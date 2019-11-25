; Run using:

; ncl opt=\"x11\" res0=10 year0=2017 trb=0
; lb=\"top\" eurec4a_p1_str_prcp.ncl

; 'res0'  = grid spacing: 10 km (10), 4.4 km (4), or 2.2 km (2)                                 
; 'year0' = analyse case from Feb 2017 (2017) or 2018 (2018)                                    
; 'opt'   = output file format (x11, pdf, png, etc)                                             
; 'trb'   = troubleshooting - print out variable info and exit (1), or run script as normal (0)  
; 'lb'    = position of labelbar on final plot (top) or (bot) 

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

; Choose which time array to read from (not sure this adds value)
  t_str   = (/"t","t"/)

; Read in correct date strings depending on year 
  if (year0 .eq. 2017) then
   dat_arr   = (/"20170206T0000Z","20170206T1200Z","20170207T0000Z",\
                 "20170207T1200Z","20170208T0000Z"/)
   dat_out   = "20170205"
  else
   dat_arr   = (/"20180209T0000Z","20180209T1200Z","20180210T0000Z",\
                 "20180210T1200Z","20180211T0000Z"/)
   dat_out   = "20180208"
  end if

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

; Total number of times 
  num_init = dimsizes(dat_arr)
  ntimes   = num_init * 12

; Create arrays to hold all data (prcp, accumulated prcp, mslp)                            
  rain_arr   = new((/ntimes,uv_size(0),uv_size(1)/),"float")
  slp_arr    = new((/ntimes,uv_size(0),uv_size(1)/),"float")
  u_arr      = new((/ntimes,uv_size(0),uv_size(1)/),"float")
  v_arr      = new((/ntimes,uv_size(0),uv_size(1)/),"float")
  spd_arr    = new((/ntimes,uv_size(0),uv_size(1)/),"float")

; Additional arrays for output with global model 
  rain_c_arr = new((/ntimes,uv_size(0),uv_size(1)/),"float")
  rain_l_arr = new((/ntimes,uv_size(0),uv_size(1)/),"float")

; Arrays to hold date strings for plotting 
  date_str   = new(ntimes,string)
  time_str   = new(ntimes,string)
  time_arr   = new(ntimes,string)
  title_arr  = new(ntimes,string)

; Also create array for accumulated precip
  rain_acc   = new((/20,uv_size(0),uv_size(1)/),"float")
  rsize      = dimsizes(rain_acc)

; Initialise counter variable for arrays above 
  dt         = 0 

; Read in chosen model data 
 do in       = 0, dimsizes(dat_arr)-1

  diri       = "/nfs/a319/earshar/eurec4a/"+year0+"/nc/"+dat_arr(in)+"_"
  fili       = diri+"EUREC4A_IC1km_"+rstr+"_pverb"
  input      = systemfunc("ls "+fili+"*.nc")
  ninput     = dimsizes(input)

  setvalues NhlGetWorkspaceObjectId
    "wsMaximumSize" : 1000000000
  end setvalues

;===============================
; Start loop over input files 
;===============================

; Initialise counter variable
  ct = 0

; Read in files one by one 
  do nf = 0,  ninput-1

; Regional model data
  f  = addfile(input(nf),"r")            ; Read in 'pverb' stream [MSLP, prcp, acc. prcp]

  if (trb .eq. 1) then 
   n = getfilevarnames(f)
   print(n)
   do a = 0, dimsizes(n)-1
    printVarSummary(f->$n(a)$ )
   end do
   exit() 
  end if 

;==================================
; Get the variables we will need
;==================================

  do it = 0, 5

  ; Time array associated with MSLP (make sure this is consistent)
    if (nf .eq. 0) then 
     time0 = f->$t_str(0)$
     time  = time0( 1:dimsizes(time0)-1 )
    else 
     time  = f->$t_str(1)$
    end if 

  ; Counter variable to read in precipitation data
    print("it = "+it+" ; ct = "+ct+" ; dt = "+dt)

;=====================================================
; Create correct date strings for each output time
;=====================================================

    month_abbr = (/"","Jan","Feb","Mar","Apr","May","Jun",\
                      "Jul","Aug","Sep","Oct","Nov","Dec"/)

    utc_date   = cd_calendar(time, 0)

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
    title_arr(dt)= sprinti("%0.2iZ", hour(it) ) + "_" + \
                   sprinti("%0.2i", day(it) ) + month_abbr(month(it) ) + \
                   "_" + year(it)

    print("Working on time: "+time_str(dt))

;==========================================================================
; Create variable to read in different precipitation arrays at each time
;==========================================================================

  ; Not sure I still need these lines below (22/11/2019)
    if (nf .eq. 0) then 
     rain_var   = (/"lsrain_1"/)
    else
     rain_var   = (/"lsrain","lsrain_3","lsrain_5","lsrain_6"/)
    end if 

    rain_var_lg = (/"lsrain_1","lsrain_3","lsrain_5","lsrain_6"/)
    rain_var_cg = (/"cvrain_1","cvrain_3","cvrain_4","cvrain_5"/)
    rain_var_tg = (/"tot_precip","tot_precip_1","tot_precip_2","tot_precip_3"/)

  ; Read in latitude/longitude
    lon      = f->longitude
    lat      = f->latitude

    print(lon(0) )
    print(lon(dimsizes(lon)-1 ) )
    print(lat(0) )
    print(lat(dimsizes(lat)-1) )
    exit()

 ; Either read in convection-permitting model data 
   if (res0 .eq. 4) then 

   ; Input into 3D array [time * lat * lon] 
     rain_arr(dt,:,:) = (/f->$rain_var$(0,0,{t0::},:)/)
     rain_arr!0       = "time"
     rain_arr!1       = "lat"
     rain_arr!2       = "lon"
     rain_arr&lat     = lat
     rain_arr&lon     = lon
     rain_arr@units   = "mm"

   ; Mean sea level pressure (one extra time in first input file)
     if (nf .eq. 0) then
      mslp = f->p(it+1,0,{t0::},:)
     else
      mslp = f->p(it,0,{t0::},:)
     end if

     mslp  = mslp / 100
     mslp@units = "hPa"

   ; Smooth MSLP
     slp_arr(dt,:,:) = smth9_Wrap(mslp, 0.5, 0.5, False)

 ; Or read in global model data 
   else
   
    if (tot .eq. 1) then 

    ; Input into 3D array [time * lat * lon]
      rain_arr(dt,:,:) = (/f->precip(0,0,{t0::},:)/)
      rain_arr!0       = "time"
      rain_arr!1       = "lat"
      rain_arr!2       = "lon"
      rain_arr&lat     = lat
      rain_arr&lon     = lon
      rain_arr@units   = "mm"
    
    else

      rain_c_arr(dt,:,:) = (/f->cvrain_1(0,0,{t0::},:)/)
      rain_c_arr!0       = "time"
      rain_c_arr!1       = "lat"
      rain_c_arr!2       = "lon"
      rain_c_arr&lat     = lat
      rain_c_arr&lon     = lon
      rain_c_arr@units   = "mm"

      rain_l_arr(dt,:,:) = (/f->lsrain_1(0,0,{t0::},:)/)
      rain_l_arr!0       = "time"
      rain_l_arr!1       = "lat"
      rain_l_arr!2       = "lon"
      rain_l_arr&lat     = lat
      rain_l_arr&lon     = lon
      rain_l_arr@units   = "mm"

    end if 

   ; Mean sea level pressure (one extra time in first input file)            
     if (nf .eq. 0) then
      mslp = f->p(it+1,0,{t0::},:)
     else
      mslp = f->p(it,0,{t0::},:)
     end if

     mslp  = mslp / 100
     mslp@units = "hPa"

   ; Smooth MSLP
     slp_arr(dt,:,:) = smth9_Wrap(mslp, 0.5, 0.5, False)

   end if 

 ; Tidy up before next iteration 
   delete([/rain_var,rain_var_lg,rain_var_cg,rain_var_tg/]) 
   delete([/utc_date,year,month,day,hour,minute,second/])

 ; Counter variables (time)
   ct  = ct + 1
   dt  = dt + 1

  end do     ; End time loop (do it = 0, tm1-1)

 end do     ; End input file loop (do nf = 0, numINPUT0-1) 

end do      ; End loop over initialisation times (do in = 0, dimsizes(dat_arr)-1)

;==============================================================
; Now calculated accumulated precipitation outside main loop 
;==============================================================

; Add components if using global model 
  if (res0 .eq. 10 .and. tot .ne. 1) then 
   rain_arr = rain_c_arr + rain_l_arr
  end if 

; First get correct units 
  rain_arr = rain_arr * 3600

; Now calculate 3-h accumulated totals using hourly rainfall rates 
  do it = 0, 19
   ts   = it * 3
   tf   = ts + 2
   rain_acc(it,:,:) = dim_sum_n_Wrap(rain_arr(ts:tf,:,:), 0)
  end do 

; Select 3-h intervals for MSLP plots as well 
  slp_plot = slp_arr(2:59:3,:,:)

; Select date strings at 3-h intervals 
  date_out = title_arr(2:59:3) 

;============================
; Loop over required times
;============================

 do it = 0, rsize(0)-1

   print("Working on time: "+date_out(it) )

  ; Output file location and type
    out_dir = "~/public_html/eurec4a/prac1/"+dstr+"/n_atl/"+dat_out+"/"
    output  = out_dir+"prcp_pmsl_"+gstr+"_"+date_out(it)
    wks = gsn_open_wks(opt,output)

;==============================================================
; Load NIMROD colour table for precip duration data
;==============================================================

  ; Load colour table
    gsn_define_colormap(wks,"radar_new")

  ; Change the colour map around & make first colour transparent
    cmap = read_colormap_file("radar_new")
    cmap(0,3) = 0.0

;==========================
; Options for plotting
;==========================

  ; 3-h precipitation
    opts_fc                              = True
    opts_fc@cnFillOn                     = True
    opts_fc@cnLineLabelInterval          = 2.0
    opts_fc@cnLineLabelFontHeightF       = 0.012
    opts_fc@cnLineLabelBackgroundColor   = "transparent"
    opts_fc@cnLineLabelPlacementMode     = "constant"
    opts_fc@cnLinesOn                    = False ; Contour lines off
    opts_fc@cnInfoLabelOn                = False ; Contour labels off
    opts_fc@cnLevelSelectionMode         = "ExplicitLevels"
    opts_fc@cnFillPalette                = cmap

  ; Match Met Office radar colours (white,blue (lgt/mid/drk),green,yellow,orange,red,pink,white)
    opts_fc@cnLevels                     = (/0.3,0.75,1.5,3.0,6.0,12.0,24.0,48.0,96.0/)
    opts_fc@cnFillColors                 = (/0,2,3,4,5,7,8,9,12,13/)

  ; Labelbar resources
    opts_fc@lbLabelBarOn                 = True
    opts_fc@lbBoxCount                   = dimsizes(opts_fc@cnFillColors)
    opts_fc@lbFillColors                 = opts_fc@cnFillColors
    opts_fc@lbLabelStrings               = sprintf("%0.1f",opts_fc@cnLevels)
    opts_fc@lbBoxEndCapStyle             = "TriangleBothEnds"    ; Labelbar end shape
    opts_fc@lbTitlePosition              = "Top"                 ; Title position
    opts_fc@lbTitleFontHeightF           = 0.015                 ; Title font height
    opts_fc@lbTitleOffsetF               = 0                     ; Lb title up/down
    opts_fc@lbPerimOn                    = False                 ; Perimeter on/off
    opts_fc@lbLabelFontHeightF           = 0.010
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
    opts_fc@lbTitleOn                    = True
    opts_fc@lbTitleFontHeightF           = 0.0125       ; Default = 0.025
    opts_fc@lbTitleFont                  = "Helvetica"
    opts_fc@lbTitleString                = "3-h precipitation (mm)"

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
    
  ; Horizontal wind vector resources                                                      
    opts_vec                             = True
    opts_vec@gsnDraw                     = False
    opts_vec@gsnFrame                    = False
    opts_vec@gsnAddCyclic                = False

    opts_vec@vcGlyphStyle                = "LineArrow"   ; draw windbarbs               
    opts_vec@vcRefMagnitudeF             = 10.0          ; ref vec = max vector         
    opts_vec@vcRefLengthF                = 0.02          ; length of reference vector   
    opts_vec@vcMinDistanceF              = 0.06          ; distance between wind barbs  
    opts_vec@vcLineArrowThicknessF       = 3.0           ; wb thickness (2.0)      
    opts_vec@vcLineArrowColor            = "black"       ; wb colour ("grey45")
    opts_vec@gsnMaximize                 = True          ; Maximise plot size           
    opts_vec@gsnRightString              = ""
    opts_vec@gsnLeftString               = ""
    opts_vec@tiXAxisString               = ""
    opts_vec@vcRefAnnoOn                 = False
    opts_vec@vcRefAnnoOrthogonalPosF     = 0.02          ; Y-location of ref vec

  ; 10-m streamlines 
    opts_str                             = True 
    opts_str@gsnDraw                     = False
    opts_str@gsnFrame                    = False
    opts_str@gsnAddCyclic                = False 
    opts_str@gsnRightString              = ""
    opts_str@gsnLeftString               = ""
    opts_str@tiXAxisString               = ""
    opts_str@tiYAxisString               = ""
;    opts_str@stLevelPalette              = "prcp_new"
    opts_str@stLevelSelectionMode        = "ExplicitLevels"
    opts_str@stLineThicknessF            = 1.0

;    if (res0 .eq. 10) then
;     opts_str@stMinDistanceF             = 0.030
;     opts_str@stMinLineSpacingF          = 0.005
;     opts_str@stArrowLengthF             = 0.007
;     opts_str@stMinArrowSpacingF         = 0.007
;     opts_str@stArrowStride              = 3
;    elseif (res0 .eq. 4) then
;     opts_str@stMinDistanceF             = 0.025  ; 0.015
;     opts_str@stMinLineSpacingF          = 0.003  ; 0.003
;     opts_str@stArrowLengthF             = 0.005
;     opts_str@stMinArrowSpacingF         = 0.005
;     opts_str@stArrowStride              = 8
;    end if

    opts_str@lbLabelBarOn                = False
;    opts_str@lbFillColors                = (/0,3,4,5,6,7,8,9,10,11,12,13,14/)
;    opts_str@lbBoxCount                  = dimsizes(opts_str@lbFillColors)
;    opts_str@lbLabelStrings              = tostring( toint( (/5., 10., 15., 20., 25., 30., \
;                                              35., 40., 45., 50., 55., 60./) ) )
;    opts_str@lbBoxEndCapStyle            = "TriangleBothEnds"
;    opts_str@lbTitlePosition             = "Top"
;    opts_str@lbTitleFontHeightF          = 0.015                 ; Title font height
;    opts_str@lbTitleOffsetF              = 0                     ; Lb title up/down
;    opts_str@lbPerimOn                   = False                 ; Perimeter on/off
;    opts_str@lbLabelFontHeightF          = 0.0125
;    opts_str@lbLabelFont                 = "Helvetica"
;    opts_str@lbPerimFill                 = 0
;    opts_str@lbPerimFillColor            = -1

;  ; Labelbar position
;    opts_str@lbOrientation                 = "Horizontal"
;    opts_str@pmLabelBarSide                = "Top"
;    opts_str@pmLabelBarWidthF              = 0.40
;    opts_str@pmLabelBarHeightF             = 0.05
;    if (lb .eq. "top") then
;     opts_str@pmLabelBarOrthogonalPosF     = -1.00
;     opts_str@pmLabelBarParallelPosF       = 0.30
;    elseif (lb .eq. "bot") then
;     opts_str@pmLabelBarOrthogonalPosF     = -0.16          ; Move lb up from centre
;     opts_str@pmLabelBarParallelPosF       = 0.30           ; Move lb left from centre
;    end if

;  ; Labelbar title resources 
;    opts_str@lbTitleOn                     = True
;    opts_str@lbTitleFontHeightF            = 0.0125       ; Default  = 0.025
;    opts_str@lbTitleFont                   = "Helvetica"
;    opts_str@lbTitleString                 = "10-m streamlines ("+u_arr@units+")"

  ; Mean sea level pressure resources
    opts_mslp                            = True
    opts_mslp@cnFillOn                   = False
    opts_mslp@cnLineColor                = "black"
    opts_mslp@cnLevelSelectionMode       = "ExplicitLevels"
    opts_mslp@cnLevels                   = ispan(980,1040,2)     ; 16 item array
    opts_mslp@cnInfoLabelOn              = False
    opts_mslp@cnLineThicknessF           = 2.0
    opts_mslp@cnLineLabelsOn             = True
    opts_mslp@cnLineLabelInterval        = 2.0
    opts_mslp@cnLevelFlags               = "LineAndLabel"

    opts_mslp@gsnDraw                    = False
    opts_mslp@gsnFrame                   = False
    opts_mslp@gsnMaximize                = True
    opts_mslp@gsnAddCyclic               = False
    opts_mslp@gsnLeftString              = ""
    opts_mslp@gsnRightString             = ""

;===================================================
; Plot the data (3-h accumulated precip and MSLP)
;===================================================

    prcp_plot_cp = gsn_csm_contour_map(wks,rain_acc(it,:,:),opts_fc)
    slp_plot_cp  = gsn_csm_contour(wks,slp_plot(it,:,:),opts_mslp)
    overlay(prcp_plot_cp, slp_plot_cp)
    plot         = prcp_plot_cp

    draw(plot)
    frame(wks)

  end do          ; End loop over input times (do it = 0, ntimes-1)

end 