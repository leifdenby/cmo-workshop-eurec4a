; Calculate liquid water path using MetUM data 

; Run using:

; ncl opt=\"x11\" res0=4 year0=2017 trb=0 lb=\"top\" eurec4a_p1_lwp.ncl 

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

; Number of pressure/model levels
  plevs      = 22 
  mlevs      = 60

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

; Create 4D arrays to hold pressure, temperature and relative humidity
; (SH --> for mixing ratio calculation)                      
  p_arr      = new((/ntimes,mlevs,uv_size(0),uv_size(1)/),"float")
  t_arr      = new((/ntimes,mlevs,uv_size(0),uv_size(1)/),"float")
  rh_arr     = new((/ntimes,mlevs,uv_size(0),uv_size(1)/),"float")

; Create 3D array to hold LWP data                                                          
  lwp_arr    = new((/ntimes,uv_size(0),uv_size(1)/),"float")

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
  f  = addfile(input(nf),"r")

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

  ; Model height levels
  ; Dimension '1' (numbering starts from 0) for all 4D variables below 
    z       = f->hybrid_ht_1

  ; Either calculate mixing ratio using 'mixhum_ptrh' function
  ; https://www.ncl.ucar.edu/Document/Functions/Built-in/mixhum_ptrh.shtml
  ; and then using mixing ratio and density to calculate LWP   

  ; Specific humidity 
    q_arr(dt,:,:,:)     = f->q_1(it,:,:,:)
    
  ; Potential temperature
    pt_arr(dt,:,:,:)    = f->theta(it,:,:,:)

  ; Pressure 
    p_arr(dt,:,:,:)     = f->p_1(it,:,:,:)

  ; (1) calculate temperature from potential temperature, giving us density 
    rho_arr(dt,:,:,:)   = 

  ; (2) 

  ; Use 'conform_dims' to create pressure array of same size as RH and and 't' arrays
  ; https://www.ncl.ucar.edu/Document/Functions/Built-in/conform_dims.shtml

  ; OR, calculate the vertical integral of 'QCL' (cloud liquid water, output on model levels  
  ; in units of kg/kg)  

  ; Cloud liquid water 
    qcl_arr(dt,:,:,:)   = f->QCL(it,:,:,:)

  ; Vertical integral using something similar to...

  ; Tidy up
    delete([/utc_date,year,month,day,hour,minute,second,time/])

  ; Advance counter variables (time)
    ct  = ct + 1
    dt  = dt + 1 

   end do     ; End time loop (do it = 0, tm1-1)

  end do      ; End input file loop (do nf = 0, numINPUT0-1)

 end do       ; End 'initialisation time' loop

;================================
; Calculate liquid water path 
;================================

; Calculate vertical integral using something similar to below... 
; See function page online (http://www.ncl.ucar.edu/Document/Functions/Built-in/dim_sum_n.shtml)
; 'dim_sum_n_Wrap' is identical to 'dim_sum_n' --> just retains metadata
  do it = 0, ntimes-1
   lwp_arr(dt,:,:) = dim_sum_n_Wrap(qcl_arr(dt,:,:,:),0)
  end do 

; If script complains about lack of lat/lon information, add a line similar to below
; This will copy the coordinate metadata from an existing variable to a new one 
;  copy_VarCoords(q_arr(:,0,:,:), tpw_arr)

;==================================
; Loop over times and plot data
;================================== 

 do it = 0, rsize-1

  print("Working on time: "+time_arr(it) )

  ; Output file location and type
    out_dir = "~/public_html/eurec4a/prac1/"+dstr+"/n_atl/"+dat_out+"/"
    output  = out_dir+"lwp_"+gstr+"_"+title_arr(it)
    wks     = gsn_open_wks(opt, output)

  ; Load colour table
  ; EDIT to colour table of your choice 
  ; (http://www.ncl.ucar.edu/Document/Graphics/color_table_gallery.shtml)
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
    opts_fc@lbPerimOn                    = False                 ; Perimeter on/off
    opts_fc@lbLabelFontHeightF           = 0.0125
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
    opts_fc@lbTitleString                = "Liquid water path ("+lwp_arr@units+")"
    opts_fc@lbTitlePosition              = "Top"            
    opts_fc@lbTitleOffsetF               = 0                

  ; Do not draw plot/advance frame 
    opts_fc@gsnDraw                      = False
    opts_fc@gsnFrame                     = False
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

  ; Add and customise title string to overlay --> possibly also EDIT for practical 2 
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

;=================
; Plot the data
;=================

  ; Filled contour plot (EDIT --> follow other scripts in directory)
  ; Notation is 'gsn_csm_contour_map' to produce the plot structure
  ; and then 'gsn_csm_contour' to overlay additional filled contour data
    lc_fill   = gsn_csm_contour_map(wks, lc_arr(it,:,:), opts_fc)

  ; Overlay additonal cloud data onto original plot using 'gsn_csm_contour'
  ; (need to create med cloud resources 'opts_fc_med')
    mc_fill   = gsn_csm_contour(wks, mc_arr(it,:,:), opts_fc_med)

  ; Also overlay upper-level cloud data if require
  ; (need to create high cloud resources 'opts_fc_high') 
    hc_fill   = gsn_csm_contour(wks, hc_arr(it,:,:), opts_fc_high)

  ; Additional line contour + wind vector plots (uncomment if needed) 
;    cont_plot = gsn_csm_contour(wks,tpw_arr(it,:,:),opts_lc)
;    vec_plot  = gsn_csm_vector(wks,u_arr(it,:,:),v_arr(it,:,:),opts_vec)

  ; Finally, overlay required plots 
    overlay(lc_fill,mc_fill)
    overlay(lc_fill,hc_fill)
    overlay(lc_fill,vec_plot)

  ; Draw plot and advance frame 
    plot = lc_fill
    draw(plot)
    frame(wks)

  end do    ; End loop over input times (do it = 0, ntimes-1)

end 