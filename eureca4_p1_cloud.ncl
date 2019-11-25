; Plot low/medium/high cloud amount for MetUM data

; Run using:

; ncl opt=\"x11\" res0=4 year0=2017 trb=0 lb=\"top\" test=0 eurec4a_p1_lwp.ncl

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

; Array sizes --> these are for practical 1 (10 and 4.4 km only) 
; EDIT --> for practical 2, we want to plot all three datasets on the 2.2 km domain  
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

; EDIT --> when producing data for practical 2, use this domain 
  t0 = 0.0
  t1 = 26.98
  n0 = 293.0
  n1 = 322.98

; Total number of times 
  num_init = dimsizes(dat_arr)
  ntimes   = num_init * 12

; Create arrays to hold all data (low, medium, high, total cloud)
  lc_arr     = new((/ntimes,uv_size(0),uv_size(1)/),"float")
  mc_arr     = new((/ntimes,uv_size(0),uv_size(1)/),"float")
  hc_arr     = new((/ntimes,uv_size(0),uv_size(1)/),"float")
  tc_arr     = new((/ntimes,uv_size(0),uv_size(1)/),"float")
  
; Arrays to hold date strings for plotting 
  date_str   = new(ntimes,string)
  time_str   = new(ntimes,string)
  time_arr   = new(ntimes,string)
  title_arr  = new(ntimes,string)

; Also create array for 3-h output 
  plot_arr   = new((/20,uv_size(0),uv_size(1)/),"float")
  rsize      = dimsizes(plot_arr)

; Initialise counter variable for arrays above 
  dt         = 0 

; Read in chosen model data 
 do in       = 0, dimsizes(dat_arr)-1

  diri       = "/nfs/a319/earshar/eurec4a/"+year0+"/nc/"+dat_arr(in)+"_"
  fili_b     = diri+"EUREC4A_IC1km_"+rstr+"_pverb"
  fili_a     = diri+"EUREC4A_IC1km_"+rstr+"_pvera"
  input_b    = systemfunc("ls "+fili_b+"*.nc")
  input_a    = systemfunc("ls "+fili_a+"*.nc")
  ninput     = dimsizes(input_b)

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

; Regional model data ('pverb' and 'pvera' streams)
  b  = addfile(input_b(nf),"r")
  a  = addfile(input_a(nf),"r")

; Arrays in first set of files contain 7 times; rest contain 6 
  if (nf .eq. 0) then 
   mxs = 6
  else
   mxs = 6 
  end if 

; Print out information about selected variables 
  if (trb .eq. 1) then 
   n = getfilevarnames(b)
   print(n)
   do a0 = 0, dimsizes(n)-1
    dims = dimsizes(b->$n(a0)$ )
    if (dims(0) .eq. mxs) then 
     printVarSummary(b->$n(a0)$ )
    end if 
    delete(dims)
   end do
   exit() 
  end if 

;==================================
; Get the variables we will need
;==================================

  do it = 0, 5

  ; Time array associated with MSLP (make sure this is consistent)
    if (nf .eq. 0) then 
     time0 = b->$t_str(0)$
     time  = time0( 1:dimsizes(time0)-1 )
    else 
     time  = b->$t_str(1)$
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
    title_arr(dt)= sprinti("%0.2i", day(it) ) + month_abbr(month(it) ) + "_" + \
                   sprinti("%0.2iZ", hour(it) ) + "_" + year(it)

    print("Working on time: "+time_str(dt))

;===================================================================
; Read in cloud data at each time and fill large array with data
;===================================================================

  ; Read in latitude/longitude
    lon      = b->longitude
    lat      = b->latitude
 
  ; Low/medium/high cloud information 
    if (nf .eq. 0) then 
     lc_arr(dt,:,:)  = b->field33(it+1,0,{t0::},:)
     mc_arr(dt,:,:)  = b->field32(it+1,0,{t0::},:)
     hc_arr(dt,:,:)  = b->field31(it+1,0,{t0::},:)
     tc_arr(dt,:,:)  = b->field30(it+1,0,{t0::},:)
    else
     lc_arr(dt,:,:)  = b->field33(it,0,{t0::},:)
     mc_arr(dt,:,:)  = b->field32(it,0,{t0::},:)
     hc_arr(dt,:,:)  = b->field31(it,0,{t0::},:)
     tc_arr(dt,:,:)  = b->field30(it,0,{t0::},:)
    end if 

  ; Also read in wind components 
    u_varname       = "x-wind"
    v_varname       = "y-wind"
    if (nf .eq. 0) then 
     u_arr(dt,:,:)  = (/a->$u_varname$(it+1,0,{t0::},:)/)
     v_arr(dt,:,:)  = (/a->$v_varname$(it+1,0,{t0::},:)/)
    else
     u_arr(dt,:,:)  = (/a->$u_varname$(it,0,{t0::},:)/)
     v_arr(dt,:,:)  = (/a->$v_varname$(it,0,{t0::},:)/)
    end if 


  ; Tidy up before next iteration 
    delete([/utc_date,year,month,day,hour,minute,second/])

  ; Counter variables (time)
    ct  = ct + 1
    dt  = dt + 1

   end do     ; End time loop (do it = 0, tm1-1)

 end do     ; End input file loop (do nf = 0, numINPUT0-1) 

end do      ; End loop over initialisation times (do in = 0, dimsizes(dat_arr)-1)

;=======================================
; Select data every 3 h for plotting 
;=======================================

  lc_plot  = lc_arr(2:59:3,:,:)
  mc_plot  = mc_arr(2:59:3,:,:)
  hc_plot  = hc_arr(2:59:3,:,:)
  tc_plot  = tc_arr(2:59:3,:,:)

; Select date strings at 3-h intervals 
  date_out = title_arr(2:59:3) 

;============================
; Loop over required times
;============================

 do it = 0, rsize(0)-1

   print("Working on time: "+date_out(it) )

  ; Output file location and type
    out_dir = "~/public_html/eurec4a/prac1/"+dstr+"/n_atl/"+dat_out+"/"
    output = out_dir+"cloud_"+gstr+"_"+date_out(it)

    wks = gsn_open_wks(opt,output)

;======================================================================
; NEED TO EDIT --> add suitable colour tables for low/med/high cloud
;======================================================================

  ; Load colour table
    gsn_define_colormap(wks,"radar_new")

  ; Change the colour map around & make first colour transparent
    cmap = read_colormap_file("radar_new")
    cmap(0,3) = 0.0

;==========================
; Options for plotting
;==========================

  ; NEED TO EDIT 
    opts_fc                              = True
    opts_fc@cnFillOn                     = True
    opts_fc@cnLineLabelInterval          = 2.0
    opts_fc@cnLineLabelFontHeightF       = 0.012
    opts_fc@cnLineLabelBackgroundColor   = "transparent"
    opts_fc@cnLineLabelPlacementMode     = "constant"

  ; Contour lines and labels off
    opts_fc@cnLinesOn                    = False
    opts_fc@cnInfoLabelOn                = False

  ; Colourmap selection 
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

  ; Labelbar end shape; perimeter on/off; label font height; label font; perimeter fill; fill colour
    opts_fc@lbBoxEndCapStyle             = "TriangleBothEnds"
    opts_fc@lbPerimOn                    = False             
    opts_fc@lbLabelFontHeightF           = 0.010
    opts_fc@lbLabelFont                  = "Helvetica"
    opts_fc@lbPerimFill                  = 0
    opts_fc@lbPerimFillColor             = -1

  ; Labelbar position --> EDIT when producing plots for practical 2 (otherwise too big)
    opts_fc@lbOrientation                = "Horizontal"
    opts_fc@pmLabelBarSide               = "Top"
    opts_fc@pmLabelBarWidthF             = 0.40
    opts_fc@pmLabelBarHeightF            = 0.05
    if (lb .eq. "top") then
     opts_fc@pmLabelBarOrthogonalPosF     = -1.00
     opts_fc@pmLabelBarParallelPosF       = 0.70
  ; Move lb up from centre; left from centre
    elseif (lb .eq. "bot") then
     opts_fc@pmLabelBarOrthogonalPosF     = -0.16
     opts_fc@pmLabelBarParallelPosF       = 0.30 
    end if

  ; Labelbar title resources (turn title on; font size; font; string; position; move up/down)
    opts_fc@lbTitleOn                    = True
    opts_fc@lbTitleFontHeightF           = 0.0125
    opts_fc@lbTitleFont                  = "Helvetica"
    opts_fc@lbTitleString                = "Low/medium/high cloud amount"
    opts_fc@lbTitlePosition              = "Top"      
    opts_fc@lbTitleOffsetF               = 0          

  ; Do not draw plot/advance frame 
    opts_fc@gsnDraw                      = False
    opts_fc@gsnFrame                     = False
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

  ; Add and customise title string to overlay --> possibly also EDIT for practical 2 
    opts_fc@tiMainString                 = date_out(it)
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
    
  ; Horizontal wind vector resources (SH --> left in, but not sure if you'll want these)
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


    opts_fc1 = True
    opts_fc1@cnFillOn                     = True
    opts_fc1@cnLineLabelInterval          = 2.0
    opts_fc1@cnLineLabelFontHeightF       = 0.012
    opts_fc1@cnLineLabelBackgroundColor   = "transparent"
    opts_fc1@cnLineLabelPlacementMode     = "constant"

  ; Contour lines and labels off
    opts_fc1@cnLinesOn                    = False
    opts_fc1@cnInfoLabelOn                = False

  ; Colourmap selection 
    opts_fc1@cnLevelSelectionMode         = "ExplicitLevels"
    ; gsn_define_colormap(wks,"radar_new1")
    ; cmap1 = read_colormap_file("radar_new")
    ; opts_fc1@cnFillPalette                = cmap1

  ; Match Met Office radar colours (white,blue (lgt/mid/drk),green,yellow,orange,red,pink,white)
    opts_fc1@cnLevels                     = (/0.3,0.75,1.5,3.0,6.0,12.0,24.0,48.0,96.0/)
    opts_fc1@cnFillColors                 = (/0,2,3,4,5,7,8,9,12,13/)

;=========================================
; Plot either MSLP or 10-m streamlines
;=========================================
 
  ; Plot data
    cloud_plot    = gsn_csm_contour_map(wks,lc_arr(it,:,:),opts_fc1)
    cloud_plot1   = gsn_csm_contour(wks,mc_arr(it,:,:),opts_fc)
    cloud_plot2   = gsn_csm_contour(wks,hc_arr(it,:,:),opts_fc)

    overlay(cloud_plot, cloud_plot1)
    overlay(cloud_plot, cloud_plot2)

    plot          = cloud_plot
    draw(plot)
    frame(wks)

  end do          ; End loop over input times (do it = 0, ntimes-1)

end 
