; Run using:

; ncl opt=\"x11\" res0=10 year=2017 var0=\"uv\" trb=0 lb=\"top\" pl=2 test=0 eurec4a_p1_pl_wind.ncl

; 'dat'   = string of the form 'mmdd' representing the model start time 
; 'opt'   = output file format (x11, pdf, etc)
; 'trb'   = troubleshooting - print out variable info (1) or not (0)
; 'tot'   = read total precipitation amount (1) or convective and large-scale separately (0)
; 'dm'    = regional (cp) or global (gl) domain
; 'var'   = variable to plot (vort, th, td, rh, ...)
; 'lb'    = plot labelbar at top (top) or bottom (bot) of plot 
; 'tt'    = turn plot title on (1) or off (0)

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
  if (var0 .eq. "uv") then 
   var_out = "uv"
  elseif (var0 .eq. "w") then 
   var_out = "vvel"
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

  rsize      = dimsizes(dat_arr)

; Total number of times (every 6 h)
  num_init   = dimsizes(dat_arr)
  ntimes     = num_init * 2

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

; Also define 3D arrays (u,v,tpw)                                                
  u_arr      = new((/ntimes,uv_size(0),uv_size(1)/),"float")
  v_arr      = new((/ntimes,uv_size(0),uv_size(1)/),"float")
  spd_arr    = new((/ntimes,uv_size(0),uv_size(1)/),"float")
  w_arr      = new((/ntimes,uv_size(0),uv_size(1)/),"float")

; Arrays to hold date strings for plotting                                       
  date_str   = new(ntimes,string)
  time_str   = new(ntimes,string)
  time_arr   = new(ntimes,string)
  title_arr  = new(ntimes,string)

; Initialise counter variable for arrays above                                   
  dt         = 0

; Read in chosen model data 
 do in       = 0, rsize-1
  
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

; EDIT -- add time array information before starting main loop ('nc_times')
  setvalues NhlGetWorkspaceObjectId
    "wsMaximumSize" : 1000000000
  end setvalues

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

    date_str(dt) = sprinti("%0.2iUTC ", hour(it) ) + \
                   sprinti("%0.2i ", day(it) ) \
                   + month_abbr(month(it) )
    time_str(dt) = sprinti("%0.2i UTC ", hour(it) ) + \
                   sprinti("%0.2i ", day(it) ) \
                   + month_abbr(month(it) ) + " " + year(it)
    time_arr(dt) = sprinti("%0.2i", day(it) ) + \
                   month_abbr(month(it) ) + \
                   "_" + sprinti("%0.2iZ", hour(it) )
    title_arr(dt)= sprinti("%0.2i", day(it) ) + month_abbr(month(it) ) + "_" + \
                   sprinti("%0.2iZ", hour(it) ) + "_" + year(it)

    print("Working on time: "+time_str(dt))

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
    u_arr(dt,:,:)    = f->$u_name$(it,pl,{t0::},:) ; {t0:t1},{n0:n1})
    v_arr(dt,:,:)    = f->$v_name$(it,pl,{t0::},:) ; {t0:t1},{n0:n1})

  ; Vertical velocity (m/s)
    w_arr(dt,:,:)    = f->dz_dt(it,pl,{t0::},:)

  ; Tidy up
    delete([/pres,time/])

  ; Advance counter variables (time)
    ct  = ct + 1
    dt  = dt + 1 

   end do     ; End time loop (do it = 0, tm1-1)

  end do      ; End input file loop (do nf = 0, numINPUT0-1)

 end do       ; End 'initialisation time' loop  

;==========================================
; Calculate vector wind from 'u' and 'v'
;==========================================

   spd_arr(:,:,:) = sqrt ( u_arr(:,:,:) ^ 2 + v_arr(:,:,:) ^ 2 )

 ; Add metadata
   spd_arr@units  = "m s~S~-1~N~"

 ; Copy coordinates
   copy_VarCoords(u_arr, spd_arr)

;=================================
; Loop over times and plot data
;=================================
 
 do it = 0, rsize-1

  print("Working on time: "+time_arr(it) )

  ; Output file location and type
    out_dir = "~/public_html/eurec4a/prac1/"+dstr+"/n_atl/"+dat_out+"/"
    output  = out_dir+var_out+"_"+pl0+"_"+gstr+"_"+title_arr(it)
    wks     = gsn_open_wks(opt, output)

  ; Load colour table (depending on chosen variable)
    if (var0 .eq. "uv") then 
     gsn_define_colormap(wks,"prcp_new")
    else
     gsn_define_colormap(wks,"n11")
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

    if (var0 .eq. "uv") then 
     opts_fc@cnLevels                     = (/2., 5., 10., 15., 20., 25., 30., \
                                              35., 40., 45., 50./)
     opts_fc@cnFillColors                 = (/4,5,6,7,8,9,10,11,12,13,14/)
    else
;     opts_fc@cnLevels                     = (/0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, \
;                                              0.7, 0.8, 0.9, 1.0/)
     opts_fc@cnLevels                     = (/0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.40, \
                                                   0.50, 0.60, 0.70, 0.80/)
     opts_fc@cnFillColors                 = (/0,2,3,4,5,6,7,8,9,10,11,12/)
    end if

  ; Labelbar resources 
    opts_fc@lbLabelBarOn                 = True
    opts_fc@lbBoxCount                   = dimsizes(opts_fc@cnFillColors)
    opts_fc@lbFillColors                 = opts_fc@cnFillColors

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
     opts_fc@pmLabelBarOrthogonalPosF    = -1.00 
     opts_fc@pmLabelBarParallelPosF      = 0.70
    elseif (lb .eq. "bot") then 
     opts_fc@pmLabelBarOrthogonalPosF    = -0.16          ; Move lb up from centre
     opts_fc@pmLabelBarParallelPosF      = 0.30           ; Move lb left from centre
    end if 

  ; Labelbar title resources 
    opts_fc@lbTitleOn                    = True
    opts_fc@lbTitleFontHeightF           = 0.0125       ; Default = 0.025
    opts_fc@lbTitleFont                  = "Helvetica"
    if (var0 .eq. "uv") then 
     opts_fc@lbTitleString               = pl0+" hPa wind ("+spd_arr@units+")"
    else
     opts_fc@lbTitleString               = pl0+" hPa vertical velocity ("+w_arr@units+")"
    end if 

    opts_fc@gsnDraw                      = False                 ; Do not draw plot
    opts_fc@gsnFrame                     = False                 ; Do not advance frame
    opts_fc@gsnAddCyclic                 = False

    opts_fc@mpLimitMode                  = "LatLon"
    opts_fc@mpMinLatF                    = lat0(0) + 0.5
    opts_fc@mpMinLonF                    = lon0(0) + 0.5
    opts_fc@mpMaxLatF                    = lat0(dimsizes(lat0)-1) - 0.5
    opts_fc@mpMaxLonF                    = lon0(dimsizes(lon0)-1) - 0.5

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

;====================================================
; Plot either horizontal wind or vertical velocity
;====================================================

    if (var0 .eq. "uv") then 
     fill_plot = gsn_csm_contour_map(wks,spd_arr(it,:,:),opts_fc)
     vec_plot  = gsn_csm_vector(wks,u_arr(it,:,:),v_arr(it,:,:),opts_vec)
     overlay(fill_plot, vec_plot)
    else
     fill_plot = gsn_csm_contour_map(wks,w_arr(it,:,:),opts_fc)
    end if 
    plot       = fill_plot

    draw(plot)
    frame(wks)

  end do    ; End loop over input times (do it = 0, ntimes-1)

end 