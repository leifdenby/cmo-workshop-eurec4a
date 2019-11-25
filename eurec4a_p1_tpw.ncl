; Calculate total precipitable water using MetUM data 

; Run using:

; ncl opt=\"x11\" res0=10 year0=2017 trb=0 lb=\"top\" pl=7 test=0 eurec4a_p1_tpw.ncl

; 'res0'  = grid spacing: 10 km (10), 4.4 km (4), or 2.2 km (2)                                 
; 'year0' = analyse case from Feb 2017 (2017) or 2018 (2018)                                    
; 'opt'   = output file format (x11, pdf, png, etc)                                             
; 'trb'   = troubleshooting - print out variable info and exit (1), or run script as normal (0)  
; 'lb'    = position of labelbar on final plot (top) or (bot) 
; 'pl'    = pressure level to calculate and plot wind vectors 

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

; Choose which time array to read from 
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

  rsize      = dimsizes(dat_arr)

; Total number of times (every 6 h)
  num_init   = dimsizes(dat_arr)
  ntimes     = num_init * 2

; Number of pressure levels (automate)
  nlevs      = 22 

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

; Create 4D to hold specific humidity data 
  q_arr      = new((/ntimes,nlevs,uv_size(0),uv_size(1)/),"float")

; Also define 3D arrays (u,v,tpw)
  tpw_arr    = new((/ntimes,uv_size(0),uv_size(1)/),"float")
  u_arr      = new((/ntimes,uv_size(0),uv_size(1)/),"float")
  v_arr      = new((/ntimes,uv_size(0),uv_size(1)/),"float")

; Arrays to hold date strings for plotting 
  date_str   = new(ntimes,string)
  time_str   = new(ntimes,string)
  time_arr   = new(ntimes,string)
  title_arr  = new(ntimes,string)

; Initialise counter variable for arrays above
  dt         = 0
 
; Read in chosen model data 
 do in       = 0, rsize-1
  
  diri       = "/nfs/a319/earshar/eurec4a/"+year0+"/nc/"+dat_arr(in)+"_"
  fili       = diri+"EUREC4A_IC1km_"+rstr+"_pb"
  input      = systemfunc("ls "+fili+"*.nc")
  ninput     = dimsizes(input)
  ntimes     = ninput

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
    dp      = pres
    dp(0)   = 0
    plevs   = dimsizes(pres)

  ; Array of pressure level spacings (Pa)
    do ps = 1, plevs-1
     dp(ps)  = pres(ps-1) - pres(ps)
    end do
    dp = dp * 100
    dp@units = "Pa"

  ; Choose pressure level to read in wind data from
    pl0 = pres(pl)

  ; Relative humidity (%)
    q_arr(dt,:,:,:)    = f->q(it,:,:,:)

  ; Horizontal wind 
    u_name             = "x-wind"
    v_name             = "y-wind" 
    u_arr(dt,:,:)      = f->$u_name$(it,pl,{t0::},:)
    v_arr(dt,:,:)      = f->$v_name$(it,pl,{t0::},:)

  ; Tidy up
    delete([/utc_date,year,month,day,hour,minute,second,time/])

  ; Advance counter variables (time)
    ct  = ct + 1
    dt  = dt + 1 

   end do     ; End time loop (do it = 0, tm1-1)

  end do      ; End input file loop (do nf = 0, numINPUT0-1)

 end do       ; End 'initialisation time' loop

;===============================================================
; Calculate total precipitable water using specific humidity
;===============================================================

; Add metadata before calculating TPW 
  q_arr!0 = "time"

; Calculate TPW using NCL function 
  tpw_arr = prcwater_dp(q_arr(time|:, latitude|:, longitude|:, p|:), dp)
  tpw_arr@long_name = "Total column precipitable water"
  tpw_arr@units     = "kg m~S~-2~N~"

; Copy lat/lon information to new array before plotting 
  copy_VarCoords(q_arr(:,0,:,:), tpw_arr)

;==================================
; Loop over times and plot data
;================================== 

 do it = 0, rsize-1

  print("Working on time: "+time_arr(it) )

  ; Output file location and type
    out_dir = "~/public_html/eurec4a/prac1/"+dstr+"/n_atl/"+dat_out+"/"
    output  = out_dir+"tpw_"+pl0+"_"+gstr+"_"+time_arr(it)
    wks     = gsn_open_wks(opt, output)

  ; Load colour table
    gsn_define_colormap(wks,"prcp_new")

;==========================
; Options for plotting
;==========================

  ; Filled contours
    opts_fc                               = True
    opts_fc@cnFillOn                      = True
    opts_fc@cnLineLabelInterval           = 2.0
    opts_fc@cnLineLabelFontHeightF        = 0.012
    opts_fc@cnLineLabelBackgroundColor    = "transparent"
    opts_fc@cnLineLabelPlacementMode      = "constant"
    opts_fc@cnLinesOn                     = False
    opts_fc@cnInfoLabelOn                 = False
    opts_fc@cnLevelSelectionMode          = "ExplicitLevels"

    opts_fc@cnLevels                      = (/10., 15., 20., 25., 30., \
                                              35., 40., 45., 47.5, 50., 52.5, 55./)
    opts_fc@cnFillColors                  = (/0,3,4,5,6,7,8,9,10,11,12,13,14/)

  ; Labelbar resources 
    opts_fc@lbLabelBarOn                 = True
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
    opts_fc@lbTitleOn                    = True
    opts_fc@lbTitleFontHeightF           = 0.0125       ; Default = 0.025
    opts_fc@lbTitleFont                  = "Helvetica"
    opts_fc@lbTitleString                = "Total precipitable water ("+tpw_arr@units+")"

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
   
  ; Add line contours for lowest values 
    opts_lc                              = True 
    opts_lc@cnFillOn                     = False
    opts_lc@cnLineColor                  = "green4"
    opts_lc@cnLevelSelectionMode         = "ExplicitLevels"
    opts_lc@cnLevels                     = (/5/)
    opts_lc@cnInfoLabelOn                = False
    opts_lc@cnLineThicknessF             = 3.0
    opts_lc@cnLineLabelsOn               = True
    opts_lc@cnLineLabelConstantSpacingF  = 1.0
    opts_lc@cnLineLabelInterval          = 1.0
    opts_lc@cnLineLabelFont              = "Helvetica"
    opts_lc@cnLineLabelFontColor         = "green4"
    opts_lc@cnLineLabelFontHeightF       = 0.010
    opts_lc@cnLevelFlags                 = "LineAndLabel"

    opts_lc@gsnDraw                      = False
    opts_lc@gsnFrame                     = False
    opts_lc@gsnMaximize                  = True
    opts_lc@gsnAddCyclic                 = False
    opts_lc@gsnLeftString                = ""
    opts_lc@gsnRightString               = ""
 
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

    fill_plot = gsn_csm_contour_map(wks,tpw_arr(it,:,:),opts_fc)
    cont_plot = gsn_csm_contour(wks,tpw_arr(it,:,:),opts_lc)
    vec_plot  = gsn_csm_vector(wks,u_arr(it,:,:),v_arr(it,:,:),opts_vec)
    overlay(fill_plot,cont_plot)
    overlay(fill_plot,vec_plot)
    plot      = fill_plot

    draw(plot)
    frame(wks)

  end do    ; End loop over input times (do it = 0, ntimes-1)

end 