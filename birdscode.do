clear all
cd "/Users/kimik/Desktop/economics & coding/LSE_24:25_1/EC2C1/EC2C1_WT/ec2c1_project/birdscode"

log using birdslog.text, text nomsg replace 





************************** setup and load data **************************

use "birds.dta", clear
save "birds_original.dta", replace
tsset circle_id year, yearly







************************** clean the data **************************

summarize
*misstable summarize
//414 missings, have checked that they are random across years & circle_id
drop if missing(ag_land_share)
*misstable summarize
//Drop those 414 obs (also removes their share‑var missings) Confirm no share‑var missings remain


/* gen miss = missing(Min_temp)
// by year
tab year miss, row nofreq  
// by circle
by circle_id: egen miss_rate = mean(miss)
summarize miss_rate */


/*gen miss_wind = missing(Min_wind) | missing(Max_wind)
tab year miss_wind, row nofreq
by circle_id: egen miss_rate = mean(mis_wind)
summarize miss_rate */




// Impute Min_wind, Max_wind, Min_snow, Max_snow, Min_temp, Max_temp including circles missing all years. (Based on the fact that weather variables are typically smooth over time within each circle, so I replace them by using linear interpolation/extrapolation using the two nearest non-missing years (one before and one after).Also have checked that they are random across years & circle_id)

// Interpolate within each circle (fills gaps for circles with at least one value)
tsset circle_id year

ipolate Min_wind  year, by(circle_id) epolate gen(Min_wind_i)
ipolate Max_wind  year, by(circle_id) epolate gen(Max_wind_i)
replace Min_wind = Min_wind_i if missing(Min_wind)
replace Max_wind = Max_wind_i if missing(Max_wind)
drop Min_wind_i Max_wind_i

ipolate Min_snow  year, by(circle_id) epolate gen(Min_snow_i)
ipolate Max_snow  year, by(circle_id) epolate gen(Max_snow_i)
replace Min_snow = Min_snow_i if missing(Min_snow)
replace Max_snow = Max_snow_i if missing(Max_snow)
drop Min_snow_i Max_snow_i

ipolate Min_temp year, by(circle_id) epolate gen(Min_temp_i)
ipolate Max_temp year, by(circle_id) epolate gen(Max_temp_i)
replace Min_temp = Min_temp_i if missing(Min_temp)
replace Max_temp = Max_temp_i if missing(Max_temp)
drop Min_temp_i Max_temp_i



// Remove implausible values (Min_temp, Max_temp, Min_wind, Max_wind, Min_snow, Max_snow)
// Drop rows with implausible weather values also drop remaining missing values which was a few.
drop if Min_temp < -50   | Min_temp > 180
drop if Max_temp < -40   | Max_temp > 200
drop if Min_wind < 0     | Min_wind > 100
drop if Max_wind < 0     | Max_wind > 150
drop if Min_snow < 0     | Min_snow > 100
drop if Max_snow < 0     | Max_snow > 500

// Replace missing bird‐ and species‐counts with 0. (on the logic that a completed survey with no record means none seen)
local bird_cnts  num_grassland num_woodland num_wetland num_otherhabitat ///
                 num_resident num_longermigration
local spec_cnts  spec_grassland spec_woodland spec_wetland spec_otherhabitat ///
                 spec_resident spec_longermigration

foreach v of local bird_cnts {
    replace `v' = 0 if missing(`v')
}
foreach v of local spec_cnts {
    replace `v' = 0 if missing(`v')
}

drop ihs_num_grassland ihs_num_woodland ihs_num_wetland  ///
     ihs_num_otherhabitat ihs_num_resident ihs_num_longermigration
drop ihs_spec_grassland ihs_spec_woodland ihs_spec_wetland ///
     ihs_spec_otherhabitat ihs_spec_resident ihs_spec_longermig

foreach v in num_grassland num_woodland num_wetland num_otherhabitat num_resident num_longermigration {
    gen ihs_`v' = asinh(`v')
}
foreach v in spec_grassland spec_woodland spec_wetland spec_otherhabitat spec_resident spec_longermigration {
    gen ihs_`v' = asinh(`v')
}


misstable summarize
summarize
* check balance
xtdescribe

* drop circles with fewer than 5 years
bysort circle_id: gen Ni = _N
*list circle_id circle_name state Ni if Ni < 5, sepby(Ni)
tab state if Ni < 5
drop if Ni < 5


* re-declare panel
tsset circle_id year
xtdescribe








************************** Classical DiD Regressions **************************

// Build the treatment timeline for shale wells and turbines

* first year each circle EVER sees a shale well
bys circle_id (year): egen first_shale = min(cond(any_shale==1, year, .))

* permanent treatment-status flag
gen treated_shale = first_shale < . 

* post indicator = 1 for years ≥ first well year in treated circles, 0 otherwise
gen post_shale = (year >= first_shale) & treated_shale
label var post_shale "Post-well (classical DiD)"

* same for wind turbines (optional) —- *
bys circle_id (year): egen first_turb = min(cond(any_turbine==1, year, .))
gen treated_turb = first_turb < .
gen post_turb   = (year >= first_turb) & treated_turb
label var post_turb "Post-turbine (classical DiD)"


// main DiD _0
xtreg ihs_num_tot post_shale i.year, fe vce(cluster circle_id)
xtreg ihs_num_tot post_turb i.year, fe vce(cluster circle_id)
	  

xtreg total_effort_counters post_shale i.year, fe vce(cluster circle_id) // significant positive effect!
xtreg total_effort_hours post_shale i.year, fe vce(cluster circle_id) //no sytematic post treatment change	



// main DiD with control-1 shale wells _1
xtreg ihs_num_tot post_shale                     ///
      Min_temp Max_temp Max_snow Max_wind        ///
	  total_effort_counters ///
      i.year, fe vce(cluster circle_id)	
est store shale_1

// main DiD with control-1 turbines _1
xtreg ihs_num_tot post_turb               ///
      Min_temp Max_temp Max_snow Max_wind ///
      total_effort_counters                  ///
      i.year, fe vce(cluster circle_id)	  
est store turb_1 	
	  	  
	 
//sinh applicable?!
summarize num_tot if post_shale == 0      // mean, SD, min–max
centile  num_tot if post_shale == 0, centile(25 50 75)

// Interpretation: Since all CBC circles have at least 12 birds (median ≈ 8 k), so the IHS transform is effectively the same as a log; we can treat any coefficient × 100 as a percent change. For log‑style models in general, that quick percent rule is fine when |β| < 0.10; beyond that, quote 100·(e^β – 1) %.	

********************************************************************************	
	
	
	
	
	

	
	
	
	
	
	
	
	
	
	
	
	

// 1-3 : Some alternatives and more robustness checks:





// 1. adding more controls (ag_land_share past_land_share (separately), cloud and rain eefcts, and water conditions)


//robust to including land shares:
xtreg ihs_num_tot post_shale               ///
      Min_temp Max_temp Max_snow Max_wind ///
      total_effort_counters                  ///
      ag_past_land_share dev_share_broad ///
      i.year, fe vce(cluster circle_id)	 
	  
xtreg ihs_num_tot post_shale               ///
      Min_temp Max_temp Max_snow Max_wind ///
      total_effort_counters                  ///
      ag_past_land_share dev_share_broad ///
      i.year, fe vce(cluster circle_id)	
	  
	  
corr ag_land_share past_land_share	  //no specific correlation!, both are very noisy
corr ag_past_land_share dev_share_broad

//By collapsing cropland share and pasture share into a single "agricultural land‐use" variable, I control for the total extent of human‐modified land around each circle without splitting hairs over whether it's pasture or crops. This soaks up the general habitat‐loss and disturbance pressure from any farming activity, reduces multicollinearity and noise from two tiny, highly‐stable covariates, and frees up precision to isolate the effect of shale wells (or turbines) on bird counts.

* turn each string into a categorical numeric var
encode AMCloud,         gen(AMCloud_cat)
encode PMCloud,         gen(PMCloud_cat)
encode Am_rain_cond_Names, gen(AmRain_cat)
encode Pm_rain_cond_Names, gen(PmRain_cat)
encode Am_snow_cond_Names, gen(AmSnow_cat)
encode Pm_snow_cond_Names, gen(PmSnow_cat)
encode StillWater,  gen(sw)
encode MovingWater, gen(mw)

tab AMCloud_cat, missing
tab PMCloud_cat, missing
tab AmRain_cat
tab PmRain_cat
tab AmSnow_cat
tab PmSnow_cat
tab sw
tab mw


pwcorr AMCloud_cat PMCloud_cat AmRain_cat AmSnow_cat PmRain_cat PmSnow_cat /// no specific correlation

preserve
// drop any obs where AM or PM cloud is Unknown (value 7) or .
drop if AMCloud_cat==7 | AMCloud_cat==. ///
         | PMCloud_cat==7 | PMCloud_cat==.
// Collapse AM+PM into one 3-level "cloudiness" factor		 
gen byte cloud_cat = .
    // both clear ⇒ all-day clear
replace cloud_cat = 0 if AMCloud_cat==1 & PMCloud_cat==1  
    // any "Partly Cloudy" (but never full Cloudy) ⇒ partly cloudy
replace cloud_cat = 1 if inlist(AMCloud_cat,5,6) | inlist(PMCloud_cat,5,6) & ///
                       !inlist(AMCloud_cat,2) & !inlist(PMCloud_cat,2)  
    // any "Cloudy" ⇒ at least some cloudy
replace cloud_cat = 2 if inlist(AMCloud_cat,2) | inlist(PMCloud_cat,2)  

label define cloud 0 "Clear all day" 1 "Partly cloudy" 2 "Cloudy/overcast"
label values cloud_cat cloud		

xtreg ihs_num_tot post_shale ///
      Min_temp Max_temp Max_snow Max_wind ///
      total_effort_counters ///
      ag_past_land_share dev_share_broad  ///
      i.cloud_cat i.year, fe vce(cluster circle_id)

testparm i.cloud_cat	

xtreg ihs_num_tot post_turb ///
      Min_temp Max_temp Max_snow Max_wind ///
      total_effort_counters ///
      ag_past_land_share dev_share_broad  ///
      i.cloud_cat i.year, fe vce(cluster circle_id)
testparm i.cloud_cat	  
restore  



preserve
drop if missing(AmRain_cat) | missing(PmRain_cat) | missing(AmSnow_cat) | missing(PmSnow_cat)

// make the new rain factor
gen byte rain_cat = .
// 0 if both slots are "no rain" (whatever code that is, say code==1)
replace rain_cat = 0 if AmRain_cat==1 & PmRain_cat==1
// 2 if either slot is "heavy" (say code==2)
replace rain_cat = 2 if inlist(AmRain_cat,2) | inlist(PmRain_cat,2)
// 1 otherwise (some light rain but no heavy)
replace rain_cat = 1 if rain_cat==.

label define rainlbl 0 "No rain" 1 "Light rain" 2 "Heavy rain"
label values rain_cat rainlbl

// same for snow
gen byte snow_cat = .
replace snow_cat = 0 if AmSnow_cat==1 & PmSnow_cat==1
replace snow_cat = 2 if inlist(AmSnow_cat,2) | inlist(PmSnow_cat,2)
replace snow_cat = 1 if snow_cat==.
label define snowlbl 0 "No snow" 1 "Light snow" 2 "Heavy snow"
label values snow_cat snowlbl

corr snow_cat rain_cat Max_snow Max_wind

xtreg ihs_num_tot post_shale ///
      Min_temp Max_temp Max_snow Max_wind ///
      total_effort_counters ///
      ag_past_land_share dev_share_broad  ///
      i.snow_cat i.rain_cat i.year, fe vce(cluster circle_id) 

testparm i.snow_cat i.rain_cat	

xtreg ihs_num_tot post_turb ///
      Min_temp Max_temp Max_snow Max_wind ///
      total_effort_counters ///
      ag_past_land_share dev_share_broad  ///
      i.snow_cat i.rain_cat i.year, fe vce(cluster circle_id)
	  
restore




preserve
tab sw, missing
tab mw, missing
corr sw mw
pwcorr Min_temp Max_snow sw mw

xtreg ihs_num_tot post_shale ///
      Min_temp Max_temp Max_snow Max_wind ///
      total_effort_counters ///
      ag_past_land_share dev_share_broad  ///
      i.sw i.mw i.year, fe vce(cluster circle_id)
  

xtreg ihs_num_tot post_turb ///
      Min_temp Max_temp Max_snow Max_wind ///
      total_effort_counters ///
      ag_past_land_share dev_share_broad  ///
      i.sw i.mw i.year, fe vce(cluster circle_id)

restore
// Still‐water coverage is a strong positive predictor of bird counts in winter—so much so that, if I omitted it, you'd bias your shale‐effect estimate by conflating fracking impacts with the simple presence (or absence) of open ponds. Moving‐water status, by contrast, doesn't appear to drive within‐circle count differences at this time of year.

//after some analysis, I have decided to add still water and land shares as control variables in the regression:


  
// recode still water
clonevar sw_orig = StillWater
gen byte sw2 = .
replace sw2 = 1 if sw_orig=="Frozen"       // or code==1
replace sw2 = 2 if sw_orig=="Open"         // code==2
replace sw2 = 3 if sw_orig=="Partly Frozen" // code==3
replace sw2 = 4 if sw_orig=="Partly Open"  // code==4
// collapse both "Unknown" and genuine . into 5
replace sw2 = 5 if sw_orig=="Unknown" | missing(sw_orig)
label define swlbl2 1 "Frozen" 2 "Open" 3 "Partly Frozen" 4 "Partly Open" 5 "Unknown/missing"
label values sw2 swlbl2

tab sw2


xtreg ihs_num_tot post_shale                   ///
        Min_temp Max_temp Max_snow Max_wind      ///
        total_effort_counters                       ///
        ag_past_land_share dev_share_broad       ///
        i.sw2 i.year, ///
        fe vce(cluster circle_id)

//joint test and store
testparm i.sw2 
estimates store shale_11

xtreg ihs_num_tot post_turb                   ///
        Min_temp Max_temp Max_snow Max_wind      ///
        total_effort_counters                       ///
        ag_past_land_share dev_share_broad       ///
        i.sw2 i.year, ///
        fe vce(cluster circle_id)
//joint test and store
testparm i.sw2 
estimates store turb_11		

********************************************************************************
	  
	  
	  
	  
	  
	  
	  
	  
	  
	  
	  
	  
	  
	  

	  
	  
	  
	  
	  
	  
	  
	  

// 2. total_effort_hours vs total_effort_counters 

/*

xtreg ihs_num_tot post_shale               ///
      Min_temp Max_temp Max_snow Max_wind ///
      total_effort_hours                  ///
      ag_past_land_share dev_share_broad ///
      i.year, fe vce(cluster circle_id)	  	

xtreg ihs_num_tot post_shale ///
      Min_temp Max_temp Max_snow Max_wind ///
      total_effort_counters ///
      ag_past_land_share dev_share_broad i.year, ///
      fe vce(cluster circle_id)
*/
// I adjust for heterogeneous birding effort using party-hours (observers × hours) per CBC protocol.  Party-hours are scheduled in advance and thus less endogenous than head-counts, which can spike if "good birds" are rumored.  -> party hours is a better control! but the problem is that it is including some strangely zero values while the counters and the birds counted are not zeros!
// in order to replace counters effort with party hours, we need to clean them manually which means loosing data variation.









// 3.cleaning total effort hours
	  	  
// Roughly 6 220 circle–years (≈ 20 % of the sample) report zero party-hours but positive counter counts and non-zero bird observations. Because observers cannot record birds without spending time in the field, these entries are treated as coding errors. The problematic rows are distributed almost evenly across pre- and post-well periods (20.5 % vs 19.6 %), so deleting them does not distort the treated-versus-control comparison, but leaving them would weaken the estimated treatment effect by mis-measuring survey effort. Consequently, I set the affected hour values to missing and drop those rows.

/*
* chech the reasoning for dropping zero effort hours:
gen byte lost_hours = (total_effort_hours == 0 & total_effort_counters > 0)
count if lost_hours
display "   → rows with bad hours:  " r(N)
count
display "   → total rows in file:   " r(N)

// How many circles lost at least one row?

bys circle_id: egen byte circle_lost = max(lost_hours)
tab circle_lost, m
display "   → circles affected: " `=r(N)' " of " _N

// Is the loss concentrated in treated–post years?

*overall
tab lost_hours post_shale, col nofreq

*only treated circles
tab lost_hours post_shale if treated_shale, col nofreq
*/
	  
gen double eff_hours_clean = total_effort_hours
replace   eff_hours_clean = . ///
      if total_effort_hours==0 & total_effort_counters>0
label var eff_hours_clean "Party-hours (0's fixed to missing)"


xtreg ihs_num_tot post_shale                   ///
        Min_temp Max_temp Max_snow Max_wind      ///
        eff_hours_clean                       ///
        ag_past_land_share dev_share_broad       ///
        i.sw2 i.year, ///
        fe vce(cluster circle_id)

//joint test and store
testparm i.sw2 
estimates store shale_2

xtreg ihs_num_tot post_turb                   ///
        Min_temp Max_temp Max_snow Max_wind      ///
        eff_hours_clean                       ///
        ag_past_land_share dev_share_broad       ///
        i.sw2 i.year, ///
        fe vce(cluster circle_id)
//joint test and store
testparm i.sw2 
estimates store turb_2	

// party-hours, a bad control: Party‑hours are conceptually attractive because they fold observer numbers and field time into a single metric and, being scheduled in advance, should be less endogenous than raw head‑counts (which can spike when "good birds" are rumoured). In practice, however, 6 k circle‑years (≈ 20 %) record zero hours yet list birds—clear coding gaps. Cleaning those rows cuts the sample by one‑fifth, drops within‑R² from 5 % to 3.7 %, makes the party‑hours coefficient nonsignificant, and pushes the post_shale estimate from –0.11 to –0.15. Because measurement error swamps the conceptual gain, we retain head‑counts as the main effort control.
********************************************************************************





























// 4. human population as a mediator
	  
* Does shale arrival predict population?  (if YES, pop is imbalanced → potential confounder; if NO, pop looks exogenous to treatment)

count if population == 0 // no zero or missing values
pwcorr lnpop Min_temp Max_temp Max_snow Max_wind total_effort_counters ///
       ag_past_land_share dev_share_broad, obs sig

	   
xtreg lnpop post_shale                   ///
        Min_temp Max_temp Max_snow Max_wind      ///
		total_effort_counters ///
        i.year, ///
        fe vce(cluster circle_id)
testparm post_shale	

xtreg lnpop post_turb                   ///
        Min_temp Max_temp Max_snow Max_wind      ///
        total_effort_counters                      ///
        i.year, ///
        fe vce(cluster circle_id)
testparm post_turb

		

* Does bigger population depress or boost the counts?
xtreg ihs_num_tot Min_temp Max_temp Max_snow Max_wind      ///
        total_effort_counters                     ///
		lnpop   ///
        i.year, ///
        fe vce(cluster circle_id)
testparm lnpop		

encode county_name, gen(county_id)
xtreg ihs_num_tot Min_temp Max_temp Max_snow Max_wind      ///
      total_effort_counters lnpop i.year, ///
      fe vce(cluster county_id)		
	  
xtreg ihs_num_tot Min_temp Max_temp Max_snow Max_wind      ///
      total_effort_counters L1.lnpop i.year, ///
      fe vce(cluster county_id)		  

* main effects:		
xtreg ihs_num_tot post_shale ///
        Min_temp Max_temp Max_snow Max_wind      ///
        total_effort_counters                     ///
        ag_past_land_share dev_share_broad       ///
		lnpop   ///
        i.sw2 i.year, ///
        fe vce(cluster circle_id)
testparm lnpop
estimates store shale_4	
		
		
xtreg ihs_num_tot post_turb  ///
        Min_temp Max_temp Max_snow Max_wind      ///
        total_effort_counters                   ///
        ag_past_land_share dev_share_broad       ///
		lnpop   ///
        i.sw2 i.year, ///
        fe vce(cluster circle_id)		
testparm lnpop
estimates store turb_4		



// to check whether more intensive fracking booms/turbines lead to bigger in‐migration surges, a simple "ever‐drilled" dummy may miss a dose–response pattern.
xtreg lnpop ihs_c_shale_production                  ///
        Min_temp Max_temp Max_snow Max_wind      ///
        total_effort_counters                      ///
        ag_past_land_share dev_share_broad       ///
        i.sw2 i.year, ///
        fe vce(cluster circle_id)

xtreg lnpop ihs_c_num_turbines                  ///
        Min_temp Max_temp Max_snow Max_wind      ///
        total_effort_counters                      ///
        ag_past_land_share dev_share_broad       ///
        i.sw2 i.year, ///
        fe vce(cluster circle_id)

// to check whether more intensive fracking booms/turbines lead to bigger in‐migration surges, a simple "ever‐drilled" dummy may miss a dose–response pattern.
xtreg lnpop ihs_c_shale_production                  ///
        Min_temp Max_temp Max_snow Max_wind      ///
        total_effort_counters                      ///
        ag_past_land_share dev_share_broad       ///
        i.sw2 i.year, ///
        fe vce(cluster circle_id)

xtreg lnpop ihs_c_num_turbines                  ///
        Min_temp Max_temp Max_snow Max_wind      ///
        total_effort_counters                      ///
        ag_past_land_share dev_share_broad       ///
        i.sw2 i.year, ///
        fe vce(cluster circle_id)		

// results are even more insignificant!		


// The three land‐use shares could be mediator candidates. not just some confounders as controls.

xtreg dev_share_broad post_shale                   ///
        Min_temp Max_temp Max_snow Max_wind      ///
		total_effort_counters ///
        i.year, ///
        fe vce(cluster circle_id)
testparm post_shale	
xtreg dev_share_broad post_turb                   ///
        Min_temp Max_temp Max_snow Max_wind      ///
		total_effort_counters ///
        i.year, ///
        fe vce(cluster circle_id)


xtreg ag_past_land_share post_shale                   ///
        Min_temp Max_temp Max_snow Max_wind      ///
		total_effort_counters ///
        i.year, ///
        fe vce(cluster circle_id)
testparm post_shale	
xtreg ag_past_land_share post_turb                   ///
        Min_temp Max_temp Max_snow Max_wind      ///
		total_effort_counters ///
        i.year, ///
        fe vce(cluster circle_id)


xtreg ihs_num_tot Min_temp Max_temp Max_snow Max_wind      ///
      total_effort_counters dev_share_broad i.year, ///
      fe vce(cluster circle_id)	
	  
xtreg ihs_num_tot Min_temp Max_temp Max_snow Max_wind      ///
      total_effort_counters ag_past_land_share i.year, ///
      fe vce(cluster circle_id)		  

// none of them even passed the first stage check. since they vary subtly over years.
// To find out how shale's impact is on birds, we need to find a mediator that both jumps when a boom hits and matters for bird behavior or detection.	  

********************************************************************************























// 5. continuous treatment DiD


xtreg ihs_num_tot                                     ///
    ihs_c_shalewells                              /// continuous "treatment" ///
	i.year, fe vce(cluster circle_id)



xtreg ihs_num_tot                                     ///
    ihs_c_shalewells                              /// continuous "treatment" ///
    Min_temp Max_temp Max_snow Max_wind              ///
    total_effort_counters                                   ///
	i.year, fe vce(cluster circle_id)
testparm ihs_c_shalewells 

xtreg ihs_num_tot                                     ///
    ihs_c_shalewells                              /// continuous "treatment" ///
    Min_temp Max_temp Max_snow Max_wind              ///
    total_effort_counters                                   ///
    ag_past_land_share dev_share_broad                ///
    i.sw2 i.year,               ///
    fe vce(cluster circle_id)
testparm ihs_c_shalewells 
estimates store continuous_shale	
	


	
xtreg ihs_num_tot                                     ///
    ihs_c_shale_production                              /// continuous "treatment" ///
	i.year, fe vce(cluster circle_id)		
	
	
xtreg ihs_num_tot                                     ///
    ihs_c_shale_production                              /// continuous "treatment" ///
    Min_temp Max_temp Max_snow Max_wind              ///
    total_effort_counters                                   ///
	i.year, fe vce(cluster circle_id)	
testparm ihs_c_shale_production
	
xtreg ihs_num_tot                                     ///
    ihs_c_shale_production                              /// continuous "treatment" ///
    Min_temp Max_temp Max_snow Max_wind              ///
    total_effort_counters                                   ///
    ag_past_land_share dev_share_broad                ///
    i.sw2 i.year,               ///
    fe vce(cluster circle_id)	
testparm ihs_c_shale_production
estimates store continuous_shale	


/*
xtreg ihs_num_tot                                     ///
    shalewells_num                              /// continuous "treatment" ///
    Min_temp Max_temp Max_snow Max_wind              ///
    total_effort_counters                                   ///
    ag_past_land_share dev_share_broad                ///
    i.sw2 i.year,               ///
    fe vce(cluster circle_id)	
	
corr c_shalewells c_shale_production shalewells_num
*/



xtreg ihs_num_tot                                     ///
    ihs_c_num_turbines                              /// continuous "treatment" ///
    i.year,               ///
    fe vce(cluster circle_id)

xtreg ihs_num_tot                                     ///
    ihs_c_num_turbines                              /// continuous "treatment" ///
    Min_temp Max_temp Max_snow Max_wind              ///
    total_effort_counters                                   ///
    i.year,               ///
    fe vce(cluster circle_id)
testparm ihs_c_num_turbines

	

xtreg ihs_num_tot                                     ///
    ihs_c_num_turbines                              /// continuous "treatment" ///
    Min_temp Max_temp Max_snow Max_wind              ///
    total_effort_counters                                   ///
    ag_past_land_share dev_share_broad                ///
    i.sw2 i.year,               ///
    fe vce(cluster circle_id)
testparm ihs_c_num_turbines
estimates store continuous_turb




/* //tried to combine both in one regression -> failed (strange results!)
corr post_shale c_shalewells

* cumulative wells by circle-year
bysort circle_id (year): gen cum_wells = sum(shalewells_num)

* define "beyond first" = max(0, cum_wells – 1)
gen wells_beyond1 = max(0, cum_wells - 1)

* normalize by area and smooth zeros
gen ihs_wells_beyond1 = asinh(wells_beyond1)

bysort circle_id (year): gen first_well = (sum(shalewells_num)>=1 & sum(shalewells_num[_n-1])==0)
xtreg ihs_num_tot                              ///
    first_well                                 /// jump at first well ///
    ihs_wells_beyond1                /// slope thereafter ///
    Min_temp Max_temp Max_snow Max_wind       ///
    eff_hours_clean                            ///
    ag_past_land_share dev_share_broad         ///
    i.rain_cat i.snow_cat i.sw2 i.year,        ///
    fe vce(cluster circle_id)
*/

********************************************************************************



























// 6. Relax the parallel pre-treatment trends assumption by including state-by-year fixed effects, which allow for differential time trends across states:
encode state, gen(state_id)




xtreg ihs_num_tot                                     ///
    ihs_c_shalewells                              /// continuous "treatment" ///
    Min_temp Max_temp Max_snow Max_wind              ///
    total_effort_counters                              ///
      i.state_id#i.year, fe vce(cluster circle_id)



xtreg ihs_num_tot                                     ///
    ihs_c_shale_production                              /// continuous "treatment" ///
    Min_temp Max_temp Max_snow Max_wind              ///
    total_effort_counters                              ///
      i.state_id#i.year, fe vce(cluster circle_id)



xtreg ihs_num_tot                                     ///
    ihs_c_num_turbines                              /// continuous "treatment" ///
    Min_temp Max_temp Max_snow Max_wind              ///
    total_effort_counters                              ///
      i.state_id#i.year, fe vce(cluster circle_id)


********************************************************************************



	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
  

  
  
// 7. try to see the parallel pre-treatment trends even though we are aware that it is conditional!
save "birds_cleaned.dta", replace



/*
//first i tried to compare some random never treated with treated groups -----> no clear results
                   

use "birds_cleaned.dta", clear
tsset circle_id year


//Sample 3 treated & 7 controls and plot their trajectories
* 1) Build one‐row file with a clean treated flag
preserve
  keep circle_id first_shale
  bysort circle_id: keep if _n==1

  // treat missing as never treated
  replace first_shale = 0 if missing(first_shale)
  gen byte treated = (first_shale > 0)

  tempfile one
  save `one'
restore

* 2a) Sample 3 treated IDs
use `one', clear
keep if treated==1
sample 3, count
gen str8 sample_group = "Treated"
tempfile tr
save `tr', replace

* 2b) Sample 7 control IDs
use `one', clear
keep if treated==0
sample 7, count
gen str8 sample_group = "Control"
tempfile ct
save `ct', replace

* 2c) Combine into one 10-row file
use `tr', clear
append using `ct'
tempfile sam
save `sam', replace

* 3) Merge those 10 circles back onto the full panel
use "birds_cleaned.dta", clear
tsset circle_id year
merge m:1 circle_id using `sam'
keep if _merge==3
drop _merge

* 4) Plot with pre/post coloring for treated circles
levelsof circle_id if sample_group=="Treated", local(tids)
levelsof circle_id if sample_group=="Control", local(cids)

local specs ""
// Treated: blue before, red after (inclusive)
foreach id of local tids {
    local specs `specs' ///
      (line ihs_num_tot year if circle_id==`id' & year < first_shale, ///
         lcolor(blue) lpattern(solid) lwidth(medium)) ///
      (line ihs_num_tot year if circle_id==`id' & year >= first_shale,  ///
         lcolor(red)  lpattern(solid) lwidth(medium))
}

// Controls: dashed‐blue entire span
foreach id of local cids {
    local specs `specs' ///
      (line ihs_num_tot year if circle_id==`id', ///
         lcolor(blue) lpattern(dash) lwidth(medium))
}

// Draw them all
twoway `specs', ///
    xlabel(2000(2)2020) ///
    xtitle("Year") ///
    ytitle("IHS Bird Count") ///
    title("Trajectories: Treated Switch from Blue→Red, Controls in Blue-Dash") ///
    legend(off)
*/	
	
	
	
//try to see over all drop in aggregate treated vs never treated circles:
use "birds_cleaned.dta", clear
tsset circle_id year

* Aggregate Trends with Average Treatment Year                                
replace first_shale = 0 if missing(first_shale)

* Flag treated vs. control
gen byte treated = (first_shale > 0)


preserve
  bysort circle_id: keep if _n == 1         // one row per circle
  keep if treated == 1                      // only treated circles
  quietly summarize first_shale
  scalar avg_treat = r(mean)               // store the mean
restore

* Collapse to group‐year means and plot both series with vertical lines

preserve
  collapse (mean) avgIHS = ihs_num_tot, by(treated year)

  twoway ///
    (line avgIHS year if treated==0,           ///
       lpattern(dash) lcolor(blue) lwidth(medium)) ///
    (line avgIHS year if treated==1,           ///
       lpattern(solid) lcolor(red) lwidth(medium)), ///
    legend(order(1 "Control" 2 "Treated") rows(1) pos(3)) ///
    xtitle("Year") ///
    ytitle("Mean IHS Bird Count") ///
    title("Aggregate Trends: Treated vs Controls") ///
    xline(2008,            lpattern(dot)      lcolor(gs12)  lwidth(thin))      /// 
    xline(`=avg_treat',    lpattern(longdash) lcolor(black) lwidth(thick))    /// avg treatment
    note("Black long‐dash = avg. first_shale year: " + string(avg_treat, "%4.1f"))
restore




//adding confidence bands: a visualization of the average treated vs. control path with confidence bands around each—so you can see whether their confidence intervals overlap pre‐treatment.	
use "birds_cleaned.dta", clear
tsset circle_id year

* Ensure first_shale is numeric and flag treated circles
replace first_shale = 0 if missing(first_shale)
gen byte treated = (first_shale > 0)	
preserve

  /* 1) Collapse to group–year mean, SD, and N */
  collapse ///
    (mean)   meanIHS = ihs_num_tot   ///
    (sd)     sdIHS   = ihs_num_tot   ///
    (count)  N      = ihs_num_tot,   ///
    by(year treated)   // swap the order here

  /* 2) Compute SE and 95% bands */
  gen seIHS  = sdIHS / sqrt(N)
  gen lower  = meanIHS - 1.96*seIHS
  gen upper  = meanIHS + 1.96*seIHS

  /* 3) Plot shaded CIs + lines */
  twoway ///
    (rarea lower upper year if treated==0, color(blue%20)) ///
    (line  meanIHS    year if treated==0, lpattern(dash) lcolor(blue) lwidth(medium)) ///
    (rarea lower upper year if treated==1, color(red%20))  ///
    (line  meanIHS    year if treated==1, lpattern(solid) lcolor(red) lwidth(medium)), ///
    legend(order(1 "Control 95% CI" 2 "Control Mean" ///
                 3 "Treated 95% CI" 4 "Treated Mean") cols(1) pos(3)) ///
    xtitle("Year") ytitle("Mean IHS Bird Count") ///
    title("Average Trends with 95% CIs: Treated vs Controls") ///
    xline(2008, lpattern(dot) lcolor(gs12))
restore

/*

//plot each group's bird counts relative to its own pre‐treatment(pre-2008 avg year of treatment for all!) average. That removes the level gap and shows us the parallel movement. (hopefully!)
use "birds_cleaned.dta", clear
tsset circle_id year

* Flag treatment
replace first_shale = 0 if missing(first_shale)
gen byte treated = (first_shale>0)

// 1) Compute each circle's pre-2008 mean once
preserve
  keep circle_id ihs_num_tot year
  keep if year < 2008

  // collapse to one row per circle
  collapse (mean) baseIHS = ihs_num_tot, by(circle_id)
  tempfile base
  save `base'
restore

// 2) Merge that baseline back on and demean
merge m:1 circle_id using `base'
drop _merge
gen ihs_demeaned = ihs_num_tot - baseIHS

// 3) Collapse to get group–year averages of the demeaned outcome
collapse (mean) avgD = ihs_demeaned, by(treated year)

// 4) Plot them together
twoway ///
  (line avgD year if treated==0, lpattern(dash) lcolor(blue) lwidth(medium)) ///
  (line avgD year if treated==1, lpattern(solid) lcolor(red) lwidth(medium)), ///
  legend(order(1 "Control" 2 "Treated") pos(3) cols(1)) ///
  xtitle("Year") ytitle("Change from Pre–2008 Mean") ///
  title("Demeaned Trends: Parallel Pre-Trends Check") ///
  xline(2008, lpattern(dot) lcolor(gs12))
*/
  
  
 
 
 
//centering each treated circle on its own pre-treatment average (instead of on the common 2000-2007 mean)
use "birds_cleaned.dta", clear
tsset circle_id year
replace first_shale = 0 if missing(first_shale)
gen byte treated = (first_shale>0)

* Compute treated circles' own pre-treatment baseline
preserve
  keep circle_id ihs_num_tot year first_shale
  gen rel = year - first_shale
  keep if rel < 0                                  // all pre-treatment years
  collapse (mean) baseT = ihs_num_tot, by(circle_id)
  tempfile tbase
  save "`tbase'"
restore

* Compute control group's common pre-treatment (2007) baseline
quietly summarize ihs_num_tot if treated==0 & year==2007
scalar baseC = r(mean)


* Merge treated baselines back on & demean everyone
merge m:1 circle_id using "`tbase'"
drop _merge
gen double baseline = cond(treated==1, baseT, baseC)
gen ihs_demeaned = ihs_num_tot - baseline


* Collapse to treated × year & control × year averages
collapse (mean) avgD = ihs_demeaned, by(treated year)


* Plot both series
twoway ///
  (line avgD year if treated==0, lpattern(dash) lcolor(blue) lwidth(medium)) ///
  (line avgD year if treated==1, lpattern(solid) lcolor(red)  lwidth(medium)), ///
  legend(order(1 "Control" 2 "Treated") pos(3) cols(1)) ///
  xtitle("Year") ///
  ytitle("Deviation from Pre-Treatment Mean") ///
  title("Demeaned Trends: Controls vs. Treated (Personal Baselines)") ///
  xline(2008, lpattern(dot) lcolor(gs12)) 


  
/*

//including total avg effort of counters
use "birds_cleaned.dta", clear
tsset circle_id year

// make sure no missing first_shale
replace first_shale = 0 if missing(first_shale)
gen byte treated = (first_shale > 0)

// compute avg treatment year
preserve
  bysort circle_id: keep if _n==1
  keep if treated
  quietly summarize first_shale
  scalar avg_treat = r(mean)
restore

// collapse both bird‐counts and effort by group–year
preserve
  collapse ///
    (mean) avgIHS   = ihs_num_tot       ///
    (mean) avgEff   = total_effort_counters,  ///
    by(treated year)

  // now plot four series: bird‐count & effort for treated/control
  twoway ///
    /// bird‐counts on yaxis(1)
    (line avgIHS year if treated==0, lpattern(dash) lcolor(blue)     lwidth(medium) yaxis(1)) ///
    (line avgIHS year if treated==1, lpattern(solid) lcolor(red)    lwidth(medium) yaxis(1)) ///
    /// efforts on yaxis(2)
    (line avgEff year if treated==0, lpattern(dash) lcolor(gs8)     lwidth(medium) yaxis(2)) ///
    (line avgEff year if treated==1, lpattern(solid) lcolor(gs8)    lwidth(medium) yaxis(2)), ///
    ///
    // dual‐axis titles
    ytitle("Mean IHS Bird Count", axis(1)) ///
    ytitle("Mean Effort (hours)",    axis(2)) ///
    ///
    xtitle("Year") ///
    title("Aggregate Trends: Counts & Effort") ///
    ///
    // legends
    legend( ///
      order(1 "Control: Count" 2 "Treated: Count" 3 "Control: Effort" 4 "Treated: Effort") ///
      rows(2) pos(11) ring(0) ) ///
    ///
    // vertical lines
    xline(2008,       lpattern(dot)      lcolor(gs12)   lwidth(thin))     ///
    xline(`=avg_treat', lpattern(longdash) lcolor(black) lwidth(thick)) ///
    note("Black long‐dash = avg. first_shale year: " + string(avg_treat, "%4.1f")) ///
    ///
    // tell Stata to draw both axes
    yaxis(1 2)
restore
*/



// event-study to check parallel pretreatment trends
use "birds_cleaned.dta", clear
tsset circle_id year

* 1) Relative time
gen rel = year - first_shale

* 2) Restrict to ±5 years around treatment
keep if inrange(rel, -5, 5)

* 3) Generate lead/lag dummies with legal names
foreach k of numlist -5/-1 {
    // k is negative: we name Dm{abs(k)}
    local name = "Dm" + string(abs(`k'))
    gen byte `name' = (rel == `k')
}
forvalues k = 0/5 {
    gen byte D`k' = (rel == `k')
}

* 4) Drop the base category (year -1)
drop Dm1

* 5) Estimate the event‐study (no factor‐var prefix)
xtreg ihs_num_tot ///
    Dm5 Dm4 Dm3 Dm2 D0 D1 D2 D3 D4 D5 ///
    Min_temp Max_temp Max_snow Max_wind ///
    total_effort_counters ag_past_land_share dev_share_broad ///
    i.sw2, ///
  fe vce(cluster circle_id)

* 6) Joint F-test that all pre‐treatment leads = 0
test (Dm5=0) (Dm4=0) (Dm3=0) (Dm2=0)

* 7) Plot the leads & lags with a horizontal zero reference line
ssc install coefplot
coefplot , ///
    vertical                             /// vertical orientation
    keep(Dm5 Dm4 Dm3 Dm2 D0 D1 D2 D3 D4 D5) ///
    drop(D0)                             /// omit the base
    yline(0)                             /// zero line at y=0
    xtitle("Years relative to first shale well") ///
    ytitle("ATT Estimate") ///
    title("Event‐Study: Pre‐trends & Dynamics")



	
	
	
	
	

	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	




// 8.1 placebo test (shale arrival):

use "birds_cleaned.dta", clear
xtset circle_id year

* Estimate your "real" model and save the true β̂  
quietly xtreg ihs_num_tot post_shale                   ///
        Min_temp Max_temp Max_snow Max_wind      ///
        total_effort_counters                       ///
        ag_past_land_share dev_share_broad       ///
        i.sw2 i.year, ///
        fe vce(cluster circle_id)
scalar b_real = _b[post_shale]


* Count how many circles are truly treated (ever have post_shale=1)
bysort circle_id: egen ever_treated = max(post_shale>0)
quietly count if ever_treated==1
local N_treated = r(N)


* Set up a postfile to collect placebo β̂s
tempfile placebo_results
postfile plh coef using `placebo_results', replace

set seed 39627236

forvalues i = 1/100 {
	capture drop post_dummy placebo_post_shale placebo_treated
    preserve
      keep circle_id
      duplicates drop
      gen rand = runiform()
      sort rand
      gen byte placebo_treated = (_n <= `N_treated')
      tempfile circles
      save `circles'
    restore

    merge m:1 circle_id using `circles'
    drop rand _merge

    * Rebuild your "post" dummy and placebo interaction
    gen post_dummy             = (year >= 2008)
    gen placebo_post_shale     = placebo_treated * post_dummy

    * Re‐run the FE regression
    quietly xtreg ihs_num_tot ///
          placebo_post_shale Min_temp Max_temp Max_snow Max_wind ///
          total_effort_counters ag_past_land_share dev_share_broad ///
          i.sw2 i.year, ///
          fe vce(cluster circle_id)

	post plh (_b[placebo_post_shale])
}

postclose plh

* Bring in the 100 binary‐DiD placebo draws and "true" β̂  
use `placebo_results', clear  
summarize coef  
local breal = b_real  

count if coef <= `breal'  
local p1 = r(N)/100  
count if abs(coef) >= abs(`breal')  
local p2 = r(N)/100  

* histogram (binary placebo)  
histogram coef, ///  
    bin(20) percent                /// y‐axis in %  
    fcolor(gs14) lcolor(none)      /// light gray bars, no border  
    xlabel(-0.06(0.02)0.06, format(%3.2f)) ///  
    ylabel(0(5)15, angle(horizontal)) ///  
    xtitle("Placebo Coefficient") ///  
    ytitle("Percent of Simulations", margin(minus 4)) ///  
    title("Placebo Distribution: post_shale ", size(medium)) ///  
    subtitle("100 draws; one‐sided p = `p1', two‐sided p = `p2'", size(small)) ///  
    xline(`breal', lpattern(dash) lwidth(medium) lcolor(blue)) ///  
    note("Dashed line = true β̂ = `=string(`breal',"%5.3f")'", ///  
         position(11) size(small)) ///  
    legend(off) ///  
    scheme(s1color)  

	
	
	
	
	
// 8.2 placebo test (cumulative shale wells):	
	
* Estimate the "true" continuous effect and save it
use "birds_cleaned.dta", clear
xtset circle_id year

quietly xtreg ihs_num_tot ///
    ihs_c_shale_production   ///
    Min_temp Max_temp Max_snow Max_wind ///
    total_effort_counters ag_past_land_share dev_share_broad ///
    i.sw2 i.year, fe vce(cluster circle_id)

scalar b_real = _b[ihs_c_shale_production]


* Save a snapshot of the full panel
tempfile base
save `base'


* Prepare a donor‐trajectory panel once
use `base', clear
keep circle_id year ihs_c_shale_production
rename circle_id   donor_id
rename ihs_c_shale_production donor_treat
tempfile treatpanel
save `treatpanel', replace


* Set up postfile for 100 placebo draws
tempfile results
capture postclose ph
postfile ph coef using `results', replace

set seed 39627236
forvalues draw = 1/100 {
    
    use `base', clear


    * a) Build original ID list
    preserve
      keep circle_id
      duplicates drop
      gen id = _n
      keep circle_id id
      tempfile idlist
      save `idlist', replace
    restore

    * Build a random donor list
    preserve
      keep circle_id
      duplicates drop
      gen u = runiform()
      sort u
      gen id = _n
      rename circle_id donor_id
      keep donor_id id
      tempfile donorlist
      save `donorlist', replace
    restore

    * Merge them to get circle→ donor mapping
    use `idlist', clear
    merge 1:1 id using `donorlist', nogenerate
    keep circle_id donor_id
    tempfile map
    save `map', replace


    * Bring map and donor trajectories back in
    use `base', clear
    merge m:1 circle_id using `map', nogenerate
    merge 1:1 donor_id year using `treatpanel', nogenerate
    rename donor_treat perm_treat

    * Re-estimate FE with the permuted treatment
    quietly xtreg ihs_num_tot ///
        perm_treat              ///
        Min_temp Max_temp Max_snow Max_wind ///
        total_effort_counters ag_past_land_share dev_share_broad ///
        i.sw2 i.year, fe vce(cluster circle_id)

    * Store the placebo β̂
    post ph (_b[perm_treat])
}
postclose ph


*  Summarize & plot the null distribution
use `results', clear
summarize coef
local breal = b_real

* compute empirical one‐ and two‐sided p‐values
count if coef <= `breal'
local p1 = r(N)/100
count if abs(coef) >= abs(`breal')
local p2 = r(N)/100

histogram coef, ///
    bin(20) percent                /// y-axis in %  
    fcolor(gs14) lcolor(none)      /// light gray bars, no border  
    xlabel(-0.06(0.02)0.08, format(%3.2f)) ///
    ylabel(0(10)20, angle(horizontal)) ///
    xtitle("Placebo Coefficient", margin(minus 4)) ///
    ytitle("Percent of Simulations", margin(minus 4)) ///
    title("Placebo Distribution: Continuous Shale Intensity", ///
          size(medium)) ///
    subtitle("100 draws; one‐sided p = `p1', two‐sided p = `p2'", size(small)) ///
    xline(`breal', lpattern(dash) lwidth(medium) lcolor(blue)) ///
    note("Dashed line = true β̂ = `=string(`breal',"%5.3f")'", ///
         position(11) size(small)) ///
    legend(off) ///
    scheme(s1color)


log close

