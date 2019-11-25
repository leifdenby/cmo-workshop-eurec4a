; Run using:

; ncl opt=\"x11\" res0=10 year=2017 var=\"vort\" trb=0  
; lb=\"top\" tt=0 pl=1 test=0 eurec4a_ex1_pl_vort.ncl

; 'res0'  = grid spacing: 10 km (10), 4.4 km (4), or 2.2 km (2)                                 
; 'year0' = analyse case from Feb 2017 (2017) or 2018 (2018)                                    
; 'opt'   = output file format (x11, pdf, png, etc)                                             
; 'trb'   = troubleshooting - print out variable info and exit (1), or run script as normal (0)  
; 'lb'    = position of labelbar on final plot (top) or (bot) 
; 'var'   = variable to plot (vort, th, td, rh, ...)

; Load main NCL functions 
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRF_contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "/nfs/a37/earshar/ncl_scripts/nepartak/archer_march2018/gsn_csm.ncl"

; Also load user-defined functions 
load "/nfs/a37/earshar/ncl_func/st_rm.ncl"
load "/nfs/a37/earshar/ncl_func/nc_times.ncl"
load "/nfs/a37/earshar/ncl_func/nc_levs.ncl"
load "/nfs/a37/earshar/ncl_func/get_grid_size.ncl"

begin

;==================================================================================
;;;;;;;;;;;;;;;;;;;;;;;;;;; Start of main part of script ;;;;;;;;;;;;;;;;;;;;;;;;;;
;==================================================================================

  print_clock("Starting main part of script...")

; Read in correct simulation data 
  if (res0 .eq. 10) then 
   rstr = "km10_GA7plus"
   gstr = "10km"
   dstr = "ga7_10km"
  elseif (res0 .eq. 4) then 
   rstr = "Atlan_4p4km_RA2M-Tmix"
   gstr = "4p4km"
   dstr = "ra2_4p4km"
  elseif (res0 .eq. 2) then 
   rstr = "km2p2_RA2M-Tmix"
   gstr = "2p2km"
   dstr = "ra2_2p2km"
  end if 

; Create output string depending on chosen variable 
  if (var .eq. "vort") then 
   var0 = "relative vorticity"
   var_out = "vort"
  elseif (var .eq. "th") then 
   var0 = "potential temperature"
   var_out = "th"
  elseif (var .eq. "td") then 
   var0 = "dewpoint temperature"
   var_out = "td"
  elseif (var .eq. "rh") then 
   var0 = "relative humidity"
   var_out = "rh"   
  end if 

; Choose which time array to read from 
  t_str   = (/"t","t"/)  

; Read in correct date strings depending on year 
  if (year .eq. 2017) then 
   dat_arr   = (/"20170206T0000Z","20170206T1200Z","20170207T0000Z",\
                 "20170207T1200Z","20170208T0000Z"/)
   dat_out   = "20170205"
  else
   dat_arr   = (/"20180209T0000Z","20180209T1200Z","20180210T0000Z",\
                 "20180210T1200Z","20180211T0000Z"/)
   dat_out   = "20180208"
  end if 
 
; Read in chosen model data 
 do in      = 0, dimsizes(dat_arr)-1
  
  diri       = "/nfs/a319/earshar/eurec4a/"+year+"/nc/"+dat_arr(in)+"_"
  fili       = diri+"EUREC4A_IC1km_"+rstr+"_pb"
  input      = systemfunc("ls "+fili+"*.nc")
  ninput     = dimsizes(input)
  ntimes     = ninput

; Read in latitude/longitude
  f           = addfile(input(0),"r")
  lon         = f->longitude
  lat         = f->latitude

; Domain subset boundaries (add 2º in each direction to accommodate plot title and colourbar)
  t0 = 0.0 
  t1 = 29.9
  n0 = 289.5
  n1 = 345.4

; Array sizes
  if (res0 .eq. 10) then 
   uv_size = (/300,560/)
   zz_size = (/300,560/)
  elseif (res0 .eq. 4) then 
   uv_size = (/750,1400/)
   zz_size = (/750,1400/)
  else
   uv_size = (/1350,1500/)
   zz_size = (/1350,1500/)
  end if 
 
; Create arrays to hold all gridded data
  u_arr     = new((/ntimes,uv_size(0),uv_size(1)/),"float")        ; Zonal wind
  v_arr     = new((/ntimes,uv_size(0),uv_size(1)/),"float")        ; Meridional wind
  zeta_arr  = new((/ntimes,uv_size(0),uv_size(1)/),"float")        ; Relative vorticity 
  div_arr   = new((/ntimes,uv_size(0),uv_size(1)/),"float")        ; Divergence
  w_arr     = new((/ntimes,uv_size(0),uv_size(1)/),"float")        ; Vertical velocity
  z_arr     = new((/ntimes,zz_size(0),zz_size(1)/),"float")        ; Geopotential height 
  rh_arr    = new((/ntimes,zz_size(0),zz_size(1)/),"float")        ; Relative humidity
  t_arr     = new((/ntimes,zz_size(0),zz_size(1)/),"float")        ; Temperature
  qcf_arr   = new((/ntimes,zz_size(0),zz_size(1)/),"float")        ; Frozen cloud water 
  qcl_arr   = new((/ntimes,zz_size(0),zz_size(1)/),"float")        ; Liquid cloud water 
  qcr_arr   = new((/ntimes,zz_size(0),zz_size(1)/),"float")        ; Rain water 
  delete(f)

; EDIT -- add time array information before starting main loop ('nc_times')
  setvalues NhlGetWorkspaceObjectId
    "wsMaximumSize" : 1000000000
  end setvalues

  date_str  = new(ntimes,string)
  time_str  = new(ntimes,string)
  out_str   = new(ntimes,string)

  time_arr  = new(ntimes,string)
  title_arr = new(ntimes,string)

;===============================
; Start loop over input files 
;===============================

; Initialise counter variable
  ct = 0

; Start loop over files 
  do nf = 0, ninput-1

; Regional model data
  f  = addfile(input(nf),"r")         ; Read in data on pressure levels

  if (trb .eq. 1) then 
   n = getfilevarnames(f)
   print(n)
   do a = 0, dimsizes(n)-1
    printVarSummary(f->$n(a)$ )
   end do
   exit() 
  end if 

  print_clock("Working on file number: "+nf)

;================================== 
; Get the variables we will need
;==================================

; This loop only contains one time, but quicker to keep existing structure for now 
  do it = 0, 0

;=====================================================
; Create correct date strings for each output time
;=====================================================

    month_abbr = (/"","Jan","Feb","Mar","Apr","May","Jun",\
                      "Jul","Aug","Sep","Oct","Nov","Dec"/)

    time   = f->t

    utc_date = cd_calendar(time, 0)

    year   = tointeger(utc_date(:,0))
    month  = tointeger(utc_date(:,1))
    day    = tointeger(utc_date(:,2))
    hour   = tointeger(utc_date(:,3))
    minute = tointeger(utc_date(:,4))
    second = utc_date(:,5)

  ; Correct for errors in the code (round up value of hour when minutes = 59)
    if (minute(it) .gt. 30) then
      hour = hour+1
    end if

    date_str(ct) = sprinti("%0.2iUTC ", hour(it) ) + \
                   sprinti("%0.2i ", day(it) ) \
                   + month_abbr(month(it) )
    time_str(ct) = sprinti("%0.2i UTC ", hour(it) ) + \
                   sprinti("%0.2i ", day(it) ) \
                   + month_abbr(month(it) ) + " " + year(it)
    out_str(ct)  = sprinti("%0.2i", day(it) ) + \
                   month_abbr(month(it) ) + \
                   "_" + sprinti("%0.2iZ", hour(it) )
    title_arr(ct)= sprinti("%0.2iZ", hour(it) ) + "_" + \
                   sprinti("%0.2i", day(it) ) + month_abbr(month(it) ) + \
                   "_" + year(it)

    time_arr(ct)  = out_str(ct)

    print("Working on time: "+time_str(ct))

;=========================
; 'pd' stream (regional)
;=========================

  ; Read in latitude & longitude grids in new files 
    lat0    = f->latitude ; ({t0::})
    lon0    = f->longitude ; ({n0:n1})

  ; Pressure levels in 'p' dimension    
    pres    = f->p

  ; Chosen pressure level for analysis
  ; '2' = 925 hPa, '4' = 850 hPa, '7' = 700 hPa, '11' = 500 hPa, '16' = 250 hPa
    pl0     = pres(pl)

  ; Wind components
    u_name           = "x-wind"
    v_name           = "y-wind"
    u_arr(ct,:,:)    = f->$u_name$(it,pl,{t0::},:) ; {t0:t1},{n0:n1})
    v_arr(ct,:,:)    = f->$v_name$(it,pl,{t0::},:) ; {t0:t1},{n0:n1})

  ; Temperature (K)
    t_arr(ct,:,:)    = f->temp(it,pl,:,:) ; {t0:t1},{n0:n1}) 
    
  ; Geopotential height (m)
    z_arr(ct,:,:)    = f->ht(it,pl,:,:) ; {t0:t1},{n0:n1})

  ; Vertical velocity (m/s)
    w_arr(ct,:,:)    = f->dz_dt(it,pl,{t0::},:)

  ; Relative humidity (%)
    rh_arr(ct,:,:)   = f->rh(it,pl,:,:)

  ; Relative vorticity (built-in function)
  ; "fatal:uv2vr_cfd: the lat,lon arrays must be dimensioned nlat and nlon, 
  ; the last two dimensions of u and v..."
    zeta_arr(ct,:,:) = uv2vr_cfd(u_arr(ct,:,:), v_arr(ct,:,:), lat0, lon0, 2)

  ; Divergence (built-in function)
    div_arr(ct,:,:)  = uv2dv_cfd(u_arr(ct,:,:), v_arr(ct,:,:), lat0, lon0, 2)

  ; Calculate horizontal grid spacing
    dx  = lon0(1) - lon0(0)                  ; Longitude
    dy  = lat0(1) - lat0(0)                  ; Latitude

  ; Tidy up
    delete([/lat0,lon0,dx,dy,pres,time/])

    ct  = ct + 1                    ; Counter variable (time)

   end do     ; End time loop (do it = 0, tm1-1)

 end do     ; End input file loop (do nf = 0, numINPUT0-1)

;===============================
; Plot data over whole domain
;===============================

 ; Read in lat/lon data again for plotting
   f        = addfile(input(1),"r") 

 ; Change relative vorticity units before plotting 
   zeta_arr       = zeta_arr * (10 ^ 5)
   zeta_arr@units = "10~S~-5~N~ s~S~-1~N~"
   copy_VarCoords(u_arr,zeta_arr)

 ; Also change units of divergence 
   div_arr       = div_arr * (10 ^ 5)
   div_arr@units = "10~S~-5~N~ s~S~-1~N~"
   copy_VarCoords(u_arr,div_arr)

   z_arr          = z_arr / 10
   z_arr@units    = "dam"

 ; Calculate potential temperature
   p_arr          = new( dimsizes(t_arr), "float")
   p_arr          = pl0
   th_arr         = pot_temp( (p_arr * 100), t_arr, -1, False)

 ; Calculate dewpoint temperature 
   td_arr         = th_arr
   td_arr         = dewtemp_trh( t_arr, rh_arr)

;==========================
; Add metadata to arrays
;==========================

 ; Relative vorticity (regional)
   zeta_arr!1 = "lat"
   zeta_arr!2 = "lon"
   zeta_arr&lat = lat
   zeta_arr&lon = lon
   zeta_arr@units = "10~S~-5~N~ s~S~-1~N~"

 ; Divergence (regional)
   div_arr!1 = "lat"
   div_arr!2 = "lon"
   div_arr&lat = lat
   div_arr&lon = lon
   div_arr@units = "10~S~-5~N~ s~S~-1~N~"

 ; Dewpoint temperature (regional)
   td_arr         = td_arr - 273.15
   td_arr@description = "Dewpoint temperature"
   td_arr@long_name   = "Dewpoint temperature"
   td_arr@units = "C"

 ; Relative humidity 
   rh_arr@units = "%"

 ; Smooth geopotential height
   z_arr = smth9_Wrap(z_arr, 0.5, 0.5, False)

 ; Also smooth relative vorticity and divergence (regional model)
   zeta_arr = smth9_Wrap(zeta_arr, 0.5, 0.5, False)
   zeta_arr = smth9_Wrap(zeta_arr, 0.5, 0.5, False)
 
   div_arr  = smth9_Wrap(div_arr, 0.5, 0.5, False)
   div_arr  = smth9_Wrap(div_arr, 0.5, 0.5, False)

 ; Test out on single time, or loop over multiple times 
   if (test .eq. 1) then 
    ts0 = 0  ; 3
    tf0 = 0  ; 4
   else
    ts0 = 0          ;  1
    tf0 = ntimes-1 ;  ntimes-2
   end if 

 do it = ts0, tf0              ; Loop over required times (21 UTC 10 Jan -- 18 UTC 11 Jan)

  print("Working on time: "+time_arr(it) )

  ; Output file location and type
    out_dir = "~/public_html/eurec4a/prac1/"+dstr+"/n_atl/"+dat_out+"/"
    output  = out_dir+var_out+"_"+pl0+"_"+gstr+"_"+out_str(it)
    wks     = gsn_open_wks(opt, output)

  ; Load colour table (depending on chosen variable)
    if (var .eq. "vort") then 
     gsn_define_colormap(wks,"BlueDarkRed18")
    elseif (var .eq. "div") then 
     gsn_define_colormap(wks,"nrl_sirkes")
    elseif (var .eq. "td" .or. var .eq. "th") then 
     gsn_define_colormap(wks,"BlAqGrYeOrReVi200")
    elseif (var .eq. "rh") then 
     gsn_define_colormap(wks,"GMT_drywet")
    end if 

;==========================
; Options for plotting
;==========================

  ; Filled contours (relative vorticity, potential temperature, dewpoint, etc)
    opts_fc                               = True
    opts_fc@cnFillOn                      = True
    opts_fc@cnLineLabelInterval           = 2.0
    opts_fc@cnLineLabelFontHeightF        = 0.012
    opts_fc@cnLineLabelBackgroundColor    = "transparent"
    opts_fc@cnLineLabelPlacementMode      = "constant"
    opts_fc@cnLinesOn                     = False
    opts_fc@cnInfoLabelOn                 = False
    opts_fc@cnLevelSelectionMode          = "ExplicitLevels"

    if (var .eq. "vort") then 

     if (test .eq. 1) then 
      opts_fc@cnLevels                    = (/-50.0, -20.0, -10.0, -5.0, -1.0, \
                                               0, 1.0, 5.0, 10.0, 20.0, 50.0/)
      opts_fc@cnFillColors                = (/2,4,6,8,9,0,0,12,13,14,16,18/)
     else 
      if (res0 .eq. 10) then 
       opts_fc@cnLevels                    = (/-10.0, -5.0, -3.0, -2.0, -1.0, \
                                                0, 1.0, 2.0, 3.0, 5.0, 10.0/)
       opts_fc@cnFillColors                = (/4,5,6,8,9,0,0,11,12,14,15,16/)
      else
       opts_fc@cnLevels                    = (/-10.0, -5.0, -2.0, \
                                                0, 2.0, 5.0, 10.0/)
       opts_fc@cnFillColors                = (/4,6,8,0,0,12,14,16/)
       opts_fc@cnSmoothingOn               = True 
      end if 
     end if 
     levs = toint(opts_fc@cnLevels)

    elseif (var .eq. "div") then 

     if (test .eq. 1) then
      opts_fc@cnLevels                     = (/0.0, 2.5, 5.0, 7.5, 10.0, 12.5, 15.0, \
                                               17.5, 20.0, 22.5, 25.0/)
      opts_fc@cnFillColors                 = (/12,11,13,14,15,16,17,18,19,20,21,22/)
     else
      if (res0 .eq. 10) then
       opts_fc@cnLevels                     = (/0.0, 2.5, 5.0, 7.5, 10.0, 12.5, 15.0, \
                                                17.5, 20.0, 22.5, 25.0/)
       opts_fc@cnFillColors                 = (/12,11,13,14,15,16,17,18,19,20,21,22/)
      else
       opts_fc@cnLevels                    = (/0.0, 2.5, 5.0, 7.5, 10.0, 12.5, 15.0, \
                                               17.5, 20.0, 22.5, 25.0/)
       opts_fc@cnFillColors                = (/12,11,13,14,15,16,17,18,19,20,21,22/)
       opts_fc@cnSmoothingOn               = True
      end if
     end if
     levs = toint(opts_fc@cnLevels)

    elseif (var .eq. "th") then 

     mean0                              = ( max(th_arr(it,:,:)) + min(th_arr(it,:,:))) / 2
     mean1                              = avg(th_arr(it,:,:) )

     print("mean (max/min) = "+mean0+" ; mean (avg) = "+mean1)

   ; Avoid crazy low values --> not sure why these were in the array (22/11/2019)
     th_arr     = where(th_arr .lt. 200.0, mean1, th_arr)

     mean                                = toint(mean1)
     levs                                = ispan(mean-8, mean+8, 1)
     opts_fc@cnFillColors                = ispan(20,190,10)       ; 17 levels (10 * 17 = 170)

    elseif (var .eq. "td") then 

     mean0                              = ( max(td_arr(it,:,:)) + min(td_arr(it,:,:))) / 2
     mean1                              = avg(td_arr(it,:,:) )

     print("mean (max/min) = "+mean0+" ; mean (avg) = "+mean1)

   ; Avoid crazy low values --> not sure why these were in the array (22/11/2019)
     td_arr     = where(td_arr .lt. -150.0, mean1, td_arr)

     mean                                = toint(mean1)
     levs                               = ispan(mean-7, mean+7, 1)
     opts_fc@cnFillColors               = ispan(20,200,12)       ; 15 levels (12 * 15 = 180)

    elseif (var .eq. "rh") then 

     if (pl .le. 7) then 
      opts_fc@cnLevels                   = (/40., 50., 60., 70., 75., 80., \
                                             85., 90., 95., 100./)
      opts_fc@cnFillColors               = (/0,22,26,30,34,38,42,46,49,52,54/)
     else
      opts_fc@cnLevels                   = (/20., 30., 40., 50., 60., 70., 80., \
                                             90., 100./)
      opts_fc@cnFillColors               = (/0,22,26,30,34,38,42,46,50,54/)
     end if 

    end if

  ; Labelbar resources 
    opts_fc@lbLabelBarOn                 = True
    opts_fc@lbBoxCount                   = dimsizes(opts_fc@cnFillColors)
    opts_fc@lbFillColors                 = opts_fc@cnFillColors
    if (var .eq. "rh") then 
     opts_fc@lbLabelStrings              = sprintf("%0.0f",opts_fc@cnLevels)
    else
     opts_fc@lbLabelStrings              = tostring(levs)     
    end if 
    opts_fc@lbBoxEndCapStyle             = "TriangleBothEnds"    ; Labelbar end shape
    opts_fc@lbTitlePosition		 = "Top"	         ; Title position
    opts_fc@lbTitleFontHeightF	         = 0.015		 ; Title font height
    opts_fc@lbTitleOffsetF		 = 0			 ; Lb title up/down
    opts_fc@lbPerimOn                    = False                 ; Perimeter on/off
    opts_fc@lbLabelFontHeightF           = 0.0125
    opts_fc@lbLabelFont                  = "Helvetica"
    opts_fc@lbPerimFill                  = 0
    opts_fc@lbPerimFillColor             = -1

  ; Labelbar position
    opts_fc@lbOrientation                = "Horizontal"
    opts_fc@pmLabelBarSide               = "Top"
    opts_fc@pmLabelBarWidthF             = 0.40
    opts_fc@pmLabelBarHeightF            = 0.05
    if (lb .eq. "top") then
     opts_fc@pmLabelBarOrthogonalPosF     = -1.00 
     opts_fc@pmLabelBarParallelPosF       = 0.70
    elseif (lb .eq. "bot") then 
     opts_fc@pmLabelBarOrthogonalPosF     = -0.16          ; Move lb up from centre
     opts_fc@pmLabelBarParallelPosF       = 0.30           ; Move lb left from centre
    end if 

  ; Labelbar title resources 
    opts_fc@lbTitleOn             = True
    opts_fc@lbTitleFontHeightF    = 0.0125       ; Default = 0.025
    opts_fc@lbTitleFont           = "Helvetica"
    if (var .eq. "vort") then
     opts_fc@lbTitleString        = pl0+" hPa "+var0+" ("+zeta_arr@units+")"
    elseif (var .eq. "div") then 
     opts_fc@lbTitleString        = pl0+" hPa "+var0+" ("+div_arr@units+")"
    elseif (var .eq. "rh") then
     opts_fc@lbTitleString        = pl0+" hPa "+var0+" ("+rh_arr@units+")"
    elseif (var .eq. "td") then
     opts_fc@lbTitleString        = pl0+" hPa "+var0+" ("+td_arr@units+")"
    elseif (var .eq. "th") then 
     opts_fc@lbTitleString        = pl0+" hPa "+var0+" ("+th_arr@units+")"
    end if

    opts_fc@gsnDraw                      = False                 ; Do not draw plot
    opts_fc@gsnFrame                     = False                 ; Do not advance frame
    opts_fc@gsnAddCyclic                 = False

    opts_fc@mpLimitMode                  = "LatLon"
    opts_fc@mpMinLatF                    = lat(0) + 0.5
    opts_fc@mpMinLonF                    = lon(0) + 0.5
    opts_fc@mpMaxLatF                    = lat(dimsizes(lat)-1) - 0.5
    opts_fc@mpMaxLonF                    = lon(dimsizes(lon)-1) - 0.5

  ; Orientate the grid to lie over the North Atlantic 
    opts_fc@mpCenterLonF                 = 180.0

    opts_fc@tmXTOn                       = "False"    ; No tickmarks on top x-axis
    opts_fc@tmYROn                       = "False"    ; No tickmarks on right y-axis

  ; Add and customise title string to overlay
    opts_fc@tiMainString                 = title_arr(it)
    opts_fc@tiMainOffsetYF               = -0.06
    opts_fc@tiMainOffsetXF               = -0.28
    opts_fc@tiMainFontHeightF            = 0.015
    opts_fc@gsnLeftString                = ""
    opts_fc@gsnRightString               = ""

  ; Additional plotting resources (land/ocean colour etc, national borders)
    opts_fc@mpDataBaseVersion            = "Ncarg4_1" ; More recent database                    
    opts_fc@mpDataSetName                = "Earth..4" ; High resolution                         
    opts_fc@mpOutlineBoundarySets        = "National" ; National borders                        
    opts_fc@mpGeophysicalLineColor       = "black"    ; Colour borders black                    
    opts_fc@mpGeophysicalLineThicknessF  = 2.0        ; Border line thickness                   

    opts_fc@pmTickMarkDisplayMode        = "Always"   ; Turn on map tickmarks                   
    opts_fc@tmXBMajorLengthF             = 0.007      ; Change tickmark length                  
    opts_fc@tmXBLabelStride              = 1          ; Skip every other label (x)              
    opts_fc@tmYLLabelStride              = 1          ; Skip every other label (y)              
    opts_fc@tmXTOn                       = "False"    ; No tickmarks on top x-axis              
    opts_fc@tmYROn                       = "False"    ; No tickmarks on right y-axis            
    opts_fc@gsnMaximize                  = True       ; Maximise plot size  

  ; Make lat/lon labels smaller
    opts_fc@tmYLLabelFontHeightF         = 0.01
    opts_fc@tmXBLabelFontHeightF         = 0.01

  ; Workaround to 'turn off' tickmarks
    opts_fc@tmXBMajorLengthF             = 0 
    opts_fc@tmYLMajorLengthF             = 0 
    opts_fc@tmXBMinorLengthF             = 0 
    opts_fc@tmYLMinorLengthF             = 0 

  ; Move lat/lon labels inside the plot boundaries 
    opts_fc@tmXBLabelDeltaF              = -2.50
    opts_fc@tmYLLabelDeltaF              = -3.75

  ; Overlay latitude & longitude grid
    opts_fc@mpGridAndLimbOn              = True       ; Turn on lat/lon lines
    opts_fc@mpGridLineDashPattern        = 2          ; Dash pattern
    opts_fc@mpGridLatSpacingF            = 5.0        ; Spacing (latitude)
    opts_fc@mpGridLonSpacingF            = 5.0        ; Spacing (longitude)
    
  ; Relative humidity line contours 
    opts_relh				   = True
    opts_relh@cnFillOn			   = False
    opts_relh@cnLineColor		   = "royalblue1"
    opts_relh@cnLevelSelectionMode         = "ExplicitLevels"
    if (pl .le. 7) then 
     opts_relh@cnLevels  		   = (/10,20,30/)
    else
     opts_relh@cnLevels                    = (/5,10,15/) 
    end if 
    opts_relh@cnInfoLabelOn		   = False
    opts_relh@cnLineThicknessF		   = 3.0
    opts_relh@cnLineLabelsOn		   = True
    opts_relh@cnLineLabelConstantSpacingF  = 1.0
    opts_relh@cnLineLabelInterval          = 1.0
    opts_relh@cnLineLabelFont              = "Helvetica"
    opts_relh@cnLineLabelFontColor         = "royalblue1"
    opts_relh@cnLineLabelFontHeightF       = 0.010
    opts_relh@cnLevelFlags                 = "LineAndLabel"

    opts_relh@gsnDraw			   = False
    opts_relh@gsnFrame			   = False
    opts_relh@gsnMaximize                  = True
    opts_relh@gsnAddCyclic                 = False
    opts_relh@gsnLeftString                = ""
    opts_relh@gsnRightString               = ""

  ; Horizontal wind vector resources                                                      
    opts_vec                               = True
    opts_vec@gsnDraw                       = False
    opts_vec@gsnFrame                      = False
    opts_vec@gsnAddCyclic                  = False

    opts_vec@vcGlyphStyle                  = "LineArrow"   ; draw windbarbs               
    opts_vec@vcRefMagnitudeF               = 10.0          ; ref vec = max vector         
    opts_vec@vcRefLengthF                  = 0.02          ; length of reference vector   
    opts_vec@vcMinDistanceF                = 0.06          ; distance between wind barbs  
    opts_vec@vcLineArrowThicknessF         = 3.0           ; windbarb line thickness      
    opts_vec@vcLineArrowColor              = "black"       ; windbarb colour              
    opts_vec@gsnMaximize                   = True          ; Maximise plot size           
    opts_vec@gsnRightString                = ""
    opts_vec@gsnLeftString                 = ""
    opts_vec@tiXAxisString                 = ""

  ; Turn on reference vector, and move it up and left 
    opts_vec@vcRefAnnoOn                   = True
    opts_vec@vcRefAnnoParallelPosF         = 0.24
    opts_vec@vcRefAnnoOrthogonalPosF       = -0.17

;=================
; Plot the data
;=================

    if(var .eq. "vort") then
      fill_plot_cp = gsn_csm_contour_map(wks,zeta_arr(it,:,:),opts_fc)  ; Relative vorticity
    elseif (var .eq. "div") then 
      fill_plot_cp = gsn_csm_contour_map(wks,div_arr(it,:,:),opts_fc)   ; Divergence 
    elseif (var .eq. "th") then
      fill_plot_cp = gsn_csm_contour_map(wks,th_arr(it,:,:),opts_fc)    ; Potential temperature
    elseif (var .eq. "td") then
      fill_plot_cp = gsn_csm_contour_map(wks,td_arr(it,:,:),opts_fc)    ; Dewpoint temperature
    elseif (var .eq. "rh") then 
      fill_plot_cp = gsn_csm_contour_map(wks,rh_arr(it,:,:),opts_fc)    ; Relative humidity
      cont_plot_cp = gsn_csm_contour(wks,rh_arr(it,:,:),opts_relh)      ; Contours (40-60%)
     overlay(fill_plot_cp, cont_plot_cp)
    end if

    vec_plot_cp  = gsn_csm_vector(wks,u_arr(it,:,:),v_arr(it,:,:),opts_vec) ; Wind vectors
    overlay(fill_plot_cp,vec_plot_cp)
    plot = fill_plot_cp

    draw(plot)
    frame(wks)

  ; Tidy up before next iteration 
    if (var .eq. "td" .or. var .eq. "th") then 
     delete([/mean,mean0,levs/])
    end if 
    delete(opts_fc@cnFillColors)
    
  end do    ; End loop over input times (do it = 0, ntimes-1)

 end do     ; End loop over initialisation times (do in = 0, dimsizes(dat_arr)-1 )

end 