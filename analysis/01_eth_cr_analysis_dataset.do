/*==============================================================================
DO FILE NAME:			00_cr_analysis_dataset
PROJECT:				Ethnicity and COVID outcomes
DATE: 					12th July 2020 
AUTHOR:					Rohini Mathur adapted from H Forbes, A Wong, A Schultze, C Rentsch,K Baskharan, E Williamson 										
DESCRIPTION OF FILE:	program 00, data management for project  
						reformat variables 
						categorise variables
						label variables 
						apply exclusion criteria
DATASETS USED:			data in memory (from analysis/input.csv)
DATASETS CREATED: 		none
OTHER OUTPUT: 			logfiles, printed to folder analysis/$logdir


							
==============================================================================*/

* Open a log file
cap log close
log using "$Logdir/01_eth_cr_create_analysis_dataset.log", replace t


di "STARTING COUNT FROM IMPORT:"
cou


**************************   INPUT REQUIRED   *********************************

* Censoring dates for each outcome (largely, last date outcome data available)
global tppcensor			= "31/07/2020"	//primary care suspected and confirmed covid
global sgsscensor			= "31/07/2020"	//testing data
global ecdscensor	 		= "31/07/2020"	//A&E admission
global inarccensor		 	= "31/07/2020"	//ICU admission and ventilation
global cpnscensor 			= "31/07/2020"	//in-hospital death
global onscensor 			= "31/07/2020"	//all death

*Start dates
global indexdate 			= "01/02/2020"


*******************************************************************************



/* CREATE VARIABLES===========================================================*/

/* DEMOGRAPHICS */ 

* Ethnicity (5 category)
replace ethnicity = . if ethnicity==.
label define ethnicity 	1 "White"  					///
						2 "Mixed" 					///
						3 "Asian or Asian British"	///
						4 "Black"  					///
						5 "Other"					
						
label values ethnicity ethnicity
tab ethnicity

* Ethnicity (16 category)
replace ethnicity_16 = . if ethnicity==.
label define ethnicity_16 									///
						1 "British or Mixed British" 		///
						2 "Irish" 							///
						3 "Other White" 					///
						4 "White + Black Caribbean" 		///
						5 "White + Black African"			///
						6 "White + Asian" 					///
 						7 "Other mixed" 					///
						8 "Indian or British Indian" 		///
						9 "Pakistani or British Pakistani" 	///
						10 "Bangladeshi or British Bangladeshi" ///
						11 "Other Asian" 					///
						12 "Caribbean" 						///
						13 "African" 						///
						14 "Other Black" 					///
						15 "Chinese" 						///
						16 "Other" 							
						
label values ethnicity_16 ethnicity_16
tab ethnicity_16,m


* Ethnicity (16 category grouped further)
* Generate a version of the full breakdown with mixed in one group
gen eth16_small = ethnicity_16
recode eth16_small 4/7 = 4
recode eth16_small 11 = 16
recode eth16_small 14 = 16

label define eth16_small 	///
						1 "British or Mixed British" ///
						2 "Irish" ///
						3 "Other White" ///
						4 "All mixed" ///
						8 "Indian" ///
						9 "Pakistani" ///
						10 "Bangladeshi" ///					
						12 "Caribbean" ///
						13 "African" ///
						15 "Chinese" ///
						16 "All Other" ///
						.u "Unknown"  
label values eth16_small eth16_small


* STP 
rename stp stp_old
bysort stp_old: gen stp = 1 if _n==1
replace stp = sum(stp)
drop stp_old

/*  IMD  */
* Group into 5 groups
rename imd imd_o
egen imd = cut(imd_o), group(5) icodes

* add one to create groups 1 - 5 
replace imd = imd + 1

* - 1 is missing, should be excluded from population 
replace imd = .u if imd_o == -1
drop imd_o

* Reverse the order (so high is more deprived)
recode imd 5 = 1 4 = 2 3 = 3 2 = 4 1 = 5 .u = .u

label define imd 1 "1 least deprived" 2 "2" 3 "3" 4 "4" 5 "5 most deprived" .u "Unknown"
label values imd imd 

/*  Age variables  */ 

* Create categorised age 
recode age 	0/17.9999=0 ///
			18/29.9999 = 1 /// 
		    30/39.9999 = 2 /// 
			40/49.9999 = 3 ///
			50/59.9999 = 4 ///
			60/69.9999 = 5 ///
			70/79.9999 = 6 ///
			80/max = 7, gen(agegroup) 

label define agegroup 	0 "0-<18" ///
						1 "18-<30" ///
						2 "30-<40" ///
						3 "40-<50" ///
						4 "50-<60" ///
						5 "60-<70" ///
						6 "70-<80" ///
						7 "80+"
						
label values agegroup agegroup






**************************** HOUSEHOLD VARS*******************************************


*Total number people in household (to check hh size)
bysort hh_id: gen hh_total=_N


****************************
*  Create required cohort  *
****************************

/* DROP ALL KIDS, AS HH COMPOSITION VARS ARE NOW MADE */
noi di "DROPPING AGE<18:" 
drop if age<18


* Age: Exclude those with implausible ages
assert age<.
noi di "DROPPING AGE<105:" 
drop if age>105

* Sex: Exclude categories other than M and F
assert inlist(sex, "M", "F", "I", "U")
noi di "DROPPING GENDER NOT M/F:" 
drop if inlist(sex, "I", "U")


gen male = 1 if sex == "M"
replace male = 0 if sex == "F"



* Create binary age (for age stratification)
recode age min/65.999999999 = 0 ///
           66/max = 1, gen(age66)

* Check there are no missing ages
assert age < .
assert agegroup < .
assert age66 < .

* Create restricted cubic splines for age
mkspline age = age, cubic nknots(4)


/* CONVERT STRINGS TO DATE====================================================*/
/* Comorb dates dates are given with month only, so adding day 
15 to enable  them to be processed as dates 			  */

*cr date for diabetes based on adjudicated type
gen diabetes=type1_diabetes if diabetes_type=="T1DM"
replace diabetes=type2_diabetes if diabetes_type=="T2DM"
replace diabetes=unknown_diabetes if diabetes_type=="UNKNOWN_DM"



foreach var of varlist 	chronic_respiratory_disease ///
						chronic_cardiac_disease  ///
						cancer  ///
						permanent_immunodeficiency  ///
						temporary_immunodeficiency  ///
						chronic_liver_disease  ///
						other_neuro  ///
						stroke			///
						dementia ///
						esrf  ///
						hypertension  ///
						asthma ///
						ra_sle_psoriasis  ///
						diabetes ///
						type1_diabetes ///
						type2_diabetes ///
						bmi_date_measured   ///
						bp_sys_date_measured   ///
						bp_dias_date_measured   ///
						creatinine_date  ///
						hba1c_mmol_per_mol_date  ///
						hba1c_percentage_date ///
						smoking_status_date ///
						{
							
		capture confirm string variable `var'
		if _rc!=0 {
			cap assert `var'==.
			rename `var' `var'_date
		}
	
		else {
				replace `var' = `var' + "-15"
				rename `var' `var'_dstr
				replace `var'_dstr = " " if `var'_dstr == "-15"
				gen `var'_date = date(`var'_dstr, "YMD") 
				order `var'_date, after(`var'_dstr)
				drop `var'_dstr
		}
	
	format `var'_date %td
}

* Note - outcome dates are handled separtely below 

* Some names too long for loops below, shorten
rename permanent_immunodeficiency_date 	perm_immunodef_date
rename temporary_immunodeficiency_date 	temp_immunodef_date
rename bmi_date_measured_date  			bmi_measured_date

/* CREATE BINARY VARIABLES====================================================*/
*  Make indicator variables for all conditions where relevant 

foreach var of varlist 	chronic_respiratory_disease ///
						chronic_cardiac_disease  ///
						cancer  ///
						perm_immunodef  ///
						temp_immunodef  ///
						chronic_liver_disease  ///
						other_neuro  ///
						stroke ///
						dementia				///
						esrf  ///
						asthma ///
						hypertension  ///
						ra_sle_psoriasis  ///
						bmi_measured_date   ///
						bp_sys_date_measured   ///
						bp_dias_date_measured   ///
						creatinine_date  ///
						hba1c_mmol_per_mol_date  ///
						hba1c_percentage_date ///
						smoking_status_date ///
						{
						
	/* date ranges are applied in python, so presence of date indicates presence of 
	  disease in the correct time frame */ 
	local newvar =  substr("`var'", 1, length("`var'") - 5)
	gen `newvar' = (`var'!=. )
	order `newvar', after(`var')
	
}



/*  Body Mass Index  */
* NB: watch for missingness

* Recode strange values 
replace bmi = . if bmi == 0 
replace bmi = . if !inrange(bmi, 15, 50)

* Restrict to within 10 years of index and aged > 16 
gen bmi_time = (date("$indexdate", "DMY") - bmi_measured_date)/365.25
gen bmi_age = age - bmi_time

replace bmi = . if bmi_age < 16 
replace bmi = . if bmi_time > 10 & bmi_time != . 

* Set to missing if no date, and vice versa 
replace bmi = . if bmi_measured_date == . 
replace bmi_measured_date = . if bmi == . 
replace bmi_measured = . if bmi == . 

* BMI (NB: watch for missingness)
gen 	bmicat = .
recode  bmicat . = 1 if bmi<18.5
recode  bmicat . = 2 if bmi<25
recode  bmicat . = 3 if bmi<30
recode  bmicat . = 4 if bmi<35
recode  bmicat . = 5 if bmi<40
recode  bmicat . = 6 if bmi<.
replace bmicat = .u if bmi>=.

label define bmicat 1 "Underweight (<18.5)" 	///
					2 "Normal (18.5-24.9)"		///
					3 "Overweight (25-29.9)"	///
					4 "Obese I (30-34.9)"		///
					5 "Obese II (35-39.9)"		///
					6 "Obese III (40+)"			///
					.u "Unknown (.u)"
label values bmicat bmicat

* Create more granular categorisation
recode bmicat 1/3 .u = 1 4=2 5=3 6=4, gen(obese4cat)

label define obese4cat 	1 "No record of obesity" 	///
						2 "Obese I (30-34.9)"		///
						3 "Obese II (35-39.9)"		///
						4 "Obese III (40+)"		
label values obese4cat obese4cat
order obese4cat, after(bmicat)



**generate BMI categories for south asians
*https://www.nice.org.uk/guidance/ph46/chapter/1-Recommendations#recommendation-2-bmi-assessment-multi-component-interventions-and-best-practice-standards

gen bmicat_sa=bmicat
replace bmicat_sa = 2 if bmi>=18.5 & bmi <23 & ethnicity  ==3
replace bmicat_sa = 3 if bmi>=23 & bmi < 27.5 & ethnicity ==3
replace bmicat_sa = 4 if bmi>=27.5 & bmi < 35 & ethnicity ==3
tab bmicat_sa

label define bmicat_sa 1 "Underweight (<18.5)" 	///
					2 "Normal (18.5-24.9 / 22.9)"		///
					3 "Overweight (25-29.9 / 23-27.4)"	///
					4 "Obese I (30-34.9 / 27.4-34.9)"		///
					5 "Obese II (35-39.9)"		///
					6 "Obese III (40+)"			///
					.u "Unknown (.u)"
label values bmicat bmicat

* Create more granular categorisation
recode bmicat_sa 1/3 .u = 1 4=2 5=3 6=4, gen(obese4cat_sa)

label define obese4cat_sa 	1 "No record of obesity" 	///
						2 "Obese I (30-34.9 / 27.5-34.9)"		///
						3 "Obese II (35-39.9)"		///
						4 "Obese III (40+)"		
label values obese4cat_sa obese4cat_sa
order obese4cat_sa, after(bmicat_sa)


/*  Smoking  */

* Smoking 
label define smoke 1 "Never" 2 "Former" 3 "Current" .u "Unknown (.u)"

gen     smoke = 1  if smoking_status == "N"
replace smoke = 2  if smoking_status == "E"
replace smoke = 3  if smoking_status == "S"
replace smoke = .u if smoking_status == "M"
replace smoke = .u if smoking_status == "" 

label values smoke smoke
drop smoking_status

* Create non-missing 3-category variable for current smoking
* Assumes missing smoking is never smoking 
recode smoke .u = 1, gen(smoke_nomiss)
order smoke_nomiss, after(smoke)
label values smoke_nomiss smoke

/* CLINICAL COMORBIDITIES */ 

/*  Cancer */
label define cancer 1 "Never" 2 "Last year" 3 "2-5 years ago" 4 "5+ years"

* Haematological malignancies
gen     cancer_cat = 4 if inrange(cancer_date, d(1/1/1900), d(1/2/2015))
replace cancer_cat = 3 if inrange(cancer_date, d(1/2/2015), d(1/2/2019))
replace cancer_cat = 2 if inrange(cancer_date, d(1/2/2019), d(1/2/2020))
recode  cancer_cat . = 1
label values cancer_cat cancer




/*  Immunosuppression  */

* Immunosuppressed:
* Permanent immunodeficiency ever, OR 
* Temporary immunodeficiency  last year
gen temp1  = 1 if perm_immunodef_date!=.
gen temp2  = inrange(temp_immunodef_date, (date("$indexdate", "DMY") - 365), date("$indexdate", "DMY"))

egen other_immuno = rowmax(temp1 temp2)
drop temp1 temp2 
order other_immuno, after(temp_immunodef)

/*  Blood pressure   */

* Categorise
gen     bpcat = 1 if bp_sys < 120 &  bp_dias < 80
replace bpcat = 2 if inrange(bp_sys, 120, 130) & bp_dias<80
replace bpcat = 3 if inrange(bp_sys, 130, 140) | inrange(bp_dias, 80, 90)
replace bpcat = 4 if (bp_sys>=140 & bp_sys<.) | (bp_dias>=90 & bp_dias<.) 
replace bpcat = .u if bp_sys>=. | bp_dias>=. | bp_sys==0 | bp_dias==0

label define bpcat 1 "Normal" 2 "Elevated" 3 "High, stage I"	///
					4 "High, stage II" .u "Unknown"
label values bpcat bpcat

recode bpcat .u=1, gen(bpcat_nomiss)
label values bpcat_nomiss bpcat

* Create non-missing indicator of known high blood pressure
gen bphigh = (bpcat==4)

/*  Hypertension  */

gen htdiag_or_highbp = bphigh
recode htdiag_or_highbp 0 = 1 if hypertension==1 


************
*   eGFR   *
************

* Set implausible creatinine values to missing (Note: zero changed to missing)
replace creatinine = . if !inrange(creatinine, 20, 3000) 
	
* Divide by 88.4 (to convert umol/l to mg/dl)
gen SCr_adj = creatinine/88.4

gen min=.
replace min = SCr_adj/0.7 if male==0
replace min = SCr_adj/0.9 if male==1
replace min = min^-0.329  if male==0
replace min = min^-0.411  if male==1
replace min = 1 if min<1

gen max=.
replace max=SCr_adj/0.7 if male==0
replace max=SCr_adj/0.9 if male==1
replace max=max^-1.209
replace max=1 if max>1

gen egfr=min*max*141
replace egfr=egfr*(0.993^age)
replace egfr=egfr*1.018 if male==0
label var egfr "egfr calculated using CKD-EPI formula with no eth"

* Categorise into ckd stages
egen egfr_cat = cut(egfr), at(0, 15, 30, 45, 60, 5000)
recode egfr_cat 0=5 15=4 30=3 45=2 60=0, generate(ckd)
* 0 = "No CKD" 	2 "stage 3a" 3 "stage 3b" 4 "stage 4" 5 "stage 5"
label define ckd 0 "No CKD" 1 "CKD"
label values ckd ckd
*label var ckd "CKD stage calc without eth"

* Convert into CKD group
*recode ckd 2/5=1, gen(chronic_kidney_disease)
*replace chronic_kidney_disease = 0 if creatinine==. 
	
recode ckd 0=1 2/3=2 4/5=3, gen(reduced_kidney_function_cat)
replace reduced_kidney_function_cat = 1 if creatinine==. 
label define reduced_kidney_function_catlab ///
	1 "None" 2 "Stage 3a/3b egfr 30-60	" 3 "Stage 4/5 egfr<30"
label values reduced_kidney_function_cat reduced_kidney_function_catlab 
lab var  reduced "Reduced kidney function"

/* Hb1AC */

/*  Diabetes severity  */

* Set zero or negative to missing
replace hba1c_percentage   = . if hba1c_percentage <= 0
replace hba1c_mmol_per_mol = . if hba1c_mmol_per_mol <= 0

/* Express  HbA1c as percentage  */ 

* Express all values as perecentage 
noi summ hba1c_percentage hba1c_mmol_per_mol 
gen 	hba1c_pct = hba1c_percentage 
replace hba1c_pct = (hba1c_mmol_per_mol/10.929)+2.15 if hba1c_mmol_per_mol<. 

* Valid % range between 0-20  
replace hba1c_pct = . if !inrange(hba1c_pct, 0, 20) 
replace hba1c_pct = round(hba1c_pct, 0.1)

/* Categorise hba1c and diabetes  */

* Group hba1c
gen 	hba1ccat = 0 if hba1c_pct <  6.5
replace hba1ccat = 1 if hba1c_pct >= 6.5  & hba1c_pct < 7.5
replace hba1ccat = 2 if hba1c_pct >= 7.5  & hba1c_pct < 8
replace hba1ccat = 3 if hba1c_pct >= 8    & hba1c_pct < 9
replace hba1ccat = 4 if hba1c_pct >= 9    & hba1c_pct !=.
label define hba1ccat 0 "<6.5%" 1">=6.5-7.4" 2">=7.5-7.9" 3">=8-8.9" 4">=9"
label values hba1ccat hba1ccat
tab hba1ccat

gen hba1c75=0 if hba1c_pct<7.5
replace hba1c75=1 if hba1c_pct>7.5 & hba1c_pct!=.
label define hba1c75 0"<7.5" 1">=7.5"

/*  Asthma  */
* Asthma  (coded: 0 No, 1 Yes no OCS, 2 Yes with OCS)
rename asthma asthmacat
recode asthmacat 0=1 1=2 2=3
label define asthmacat 1 "No" 2 "Yes, no OCS" 3 "Yes with OCS"
label values asthmacat asthmacat

gen asthma = (asthmacat==2|asthmacat==3)


/* OUTCOME AND SURVIVAL TIME==================================================*/

/*  Cohort entry and censor dates  */
* Date of cohort entry, 1 Mar 2020
gen enter_date = date("$indexdate", "DMY")

* Date of study end (typically: last date of outcome data available)
gen tppcensor_date    	    	= date("$tppcensor", 	"DMY")
gen sgsscensor_date 	    	= date("$sgsscensor", 	"DMY")
gen  ecdscensor_date			= date("$ecdscensor", 	"DMY")
gen inarccensor_date  			= date("$inarccensor", 	"DMY")
gen cpnscensor_date				= date("$cpnscensor", 	"DMY")
gen onscensor_date 	    		= date("$onscensor", 	"DMY")


	
/****   Outcome definitions   ****/
ren primary_care_suspect_case	suspected_date
ren primary_care_case			confirmed_date
ren first_tested_for_covid		tested_date
ren first_positive_test_date	positivetest_date
ren a_e_consult_date 			ae_date
ren icu_date_admitted			icu_date
*ren icu_date_ventilated        ventilation_date
ren died_date_cpns				cpnsdeath_date
ren died_date_ons				onsdeath_date

* Date of Covid death in ONS
gen onscoviddeath_date = onsdeath_date if died_ons_covid_flag_any == 1

* Date of non-COVID death in ONS 
* If missing date of death resulting died_date will also be missing
gen ons_noncoviddeath_date = onsdeath_date if died_ons_covid_flag_any != 1 

/* CONVERT STRINGS TO DATE====================================================*/
* Recode to dates from the strings 
foreach var of varlist 	suspected_date ///
						confirmed_date ///
						tested_date ///
						positivetest_date /// 	
						ae_date /// 
						icu_date /// 	ventilation_date ///
						cpnsdeath_date 	///
						onsdeath_date ///
						onscoviddeath_date ///
						ons_noncoviddeath_date ///						
				{
						
	confirm string variable `var'
	rename `var' `var'_dstr
	gen `var' = date(`var'_dstr, "YMD")
	drop `var'_dstr
	format `var' %td 

}



format *date* %td

* Binary indicators for outcomes
local p"suspected confirmed tested positivetest ae icu  cpnsdeath onsdeath onscoviddeath ons_noncoviddeath" //ventilation
foreach i of local p {
		gen `i'=0
		replace  `i'=1 if `i'_date < .
		tab `i'
}


/**** Create survival times  ****/
* For looping later, name must be stime_binary_outcome_name

* Survival time = last followup date (first: end study, death, or that outcome)
gen stime_suspected = min(tppcensor_date, onsdeath_date, suspected_date)
gen stime_confirmed = min(tppcensor_date, onsdeath_date, confirmed_date)
gen stime_tested = min(sgsscensor_date, onsdeath_date, tested_date)
gen stime_positivetest = min(sgsscensor_date, onsdeath_date, positivetest_date)
gen stime_ae = min(ecdscensor_date, onsdeath_date, ae_date)
gen stime_icu = min(inarccensor_date, onsdeath_date, icu_date)
gen stime_ventilation = min(inarccensor_date, onsdeath_date) //*ventilation_date)
gen stime_cpnsdeath = min(cpnscensor_date, cpnsdeath_date)
gen stime_onsdeath = min(onscensor_date, onsdeath_date )
gen stime_onscoviddeath = min(onscensor_date, onscoviddeath_date )
gen stime_ons_noncoviddeath = min(onscensor_date, ons_noncoviddeath_date )

/* If outcome was after censoring occurred, set to zero
replace covid_death_itu 	= 0 if (date_covid_death_itu	> onscoviddeathcensor_date) 
replace covid_tpp_prob_or_susp = 0 if (date_covid_tpp_prob_or_susp > onscoviddeathcensor_date)
replace covid_tpp_prob = 0 if (date_covid_tpp_prob > onscoviddeathcensor_date)
*/

* Format date variables
format  stime* %td 


/* LABEL VARIABLES============================================================*/
*  Label variables you are intending to keep, drop the rest 

*HH variable
label var  hh_size "Number people in household"
label var  hh_id "Household ID"


* Demographics
label var patient_id				"Patient ID"
label var age 						"Age (years)"
label var agegroup					"Grouped age"
label var age66 					"66 years and older"
label var sex 						"Sex"
label var male 						"Male"
label var bmi 						"Body Mass Index (BMI, kg/m2)"
label var bmicat 					"BMI"
label var bmicat_sa					"BMI with SA categories"
label var bmi_measured_date  		"Body Mass Index (BMI, kg/m2), date measured"
label var obese4cat					"Obesity (4 categories)"
label var obese4cat_sa				"Obesity with SA categories"
label var smoke		 				"Smoking status"
label var smoke_nomiss	 			"Smoking status (missing set to non)"
label var imd 						"Index of Multiple Deprivation (IMD)"
label var ethnicity					"Eth 5 categories"
label var ethnicity_16				"Eth 16 categories"
label var eth16_small				"Eth 16 collapsed"
label var stp 						"Sustainability and Transformation Partnership"
label var age1 						"Age spline 1"
label var age2 						"Age spline 2"
label var age3 						"Age spline 3"
lab var hh_total					"calculated No of ppl in household"

* Comorbidities of interest 
label var asthma						"Asthma category"
label var egfr_cat						"Calculated eGFR"
label var hypertension				    "Diagnosed hypertension"
label var chronic_respiratory_disease 	"Chronic Respiratory Diseases"
label var chronic_cardiac_disease 		"Chronic Cardiac Diseases"
label var diabetes_type						"Diabetes by type"
label var diabetes_exeter_os			"Diabetes exeter type"
label var cancer						"Cancer"
label var other_immuno					"Immunosuppressed (combination algorithm)"
label var chronic_liver_disease 		"Chronic liver disease"
label var other_neuro 					"Neurological disease"			
label var stroke		 			    "Stroke"
lab var dementia						"Dementia"							
label var ra_sle_psoriasis				"Autoimmune disease"
lab var egfr							"eGFR"
lab var perm_immunodef  				"Permanent immunosuppression"
lab var temp_immunodef  				"Temporary immunosuppression"

label var hypertension_date			   		"Diagnosed hypertension Date"
label var chronic_respiratory_disease_date 	"Other Respiratory Diseases Date"
label var chronic_cardiac_disease_date		"Other Heart Diseases Date"
label var diabetes_date						"Diabetes Date"
label var cancer_date 						"Cancer Date"
label var chronic_liver_disease_date  		"Chronic liver disease Date"
label var other_neuro_date 					"Neurological disease  Date"
label var stroke_date			    		"Stroke date"		
label var dementia_date						"DDementia date"					
label var ra_sle_psoriasis_date 			"Autoimmune disease  Date"
lab var perm_immunodef_date  				"Permanent immunosuppression date"
lab var temp_immunodef_date   				"Temporary immunosuppression date"
lab var  bphigh 							"non-missing indicator of known high blood pressure"
lab var bpcat 								"Blood pressure four levels, non-missing"
lab var htdiag_or_highbp 					"High blood pressure or hypertension diagnosis"

* Outcomes and follow-up
label var enter_date					"Date of study entry"

label var tppcensor				 		"Date of admin censoring for covid TPP cases"
label var sgsscensor				 	"Date of admin censoring for SGSS testing data"
label var ecdscensor			 		"Date of admin censoring for A&E attendance"
label var inarccensor				 	"Date of admin censoring for ITU admissions and ventilation events"
label var onscensor				 		"Date of admin censoring for ONS deaths"
label var cpnscensor					"Date of admin censoring for CPNS deaths"

label var suspected_date				"Failure/censoring indicator for outcome: suspected case"
label var confirmed_date				"Failure/censoring indicator for outcome: covid confirmed case"
label var tested_date					"Failure/censoring indicator for outcome: SGSS test performed"
label var positivetest_date				"Failure/censoring indicator for outcome: SGSS test positive"
label var ae_date						"Failure/censoring indicator for outcome: A&E Attendance"
label var icu_date						"Failure/censoring indicator for outcome: ICU Admission"
*label var ventilation_date				"Failure/censoring indicator for outcome: ICU Ventilation"
label var cpnsdeath_date				"Failure/censoring indicator for outcome: CPNS death"
label var onsdeath_date					"Failure/censoring indicator for outcome: ONS death any cause"
label var onscoviddeath_date			"Failure/censoring indicator for outcome: ONS COVID death"
label var ons_noncoviddeath_date		"Failure/censoring indicator for outcome: ONS non-COVID death"

* Survival times
label var stime_suspected 				"Survival time (date); outcome suspected case"
label var stime_confirmed 				"Survival time (date); outcome confirmed case"
label var stime_tested 					"Survival time (date); outcome SGSS test performed"
label var stime_positivetest 			"Survival time (date); outcome SGSS test positive"
label var stime_ae 						"Survival time (date); outcome A&E Attendance"
label var stime_icu 					"Survival time (date); outcome ICU Admission"
label var stime_ventilation				"Survival time (date); outcome ICU Ventilation"
label var stime_cpnsdeath 				"Survival time (date); outcome CPNS death"
label var stime_onsdeath 				"Survival time (date); outcome ONS death any cause"
label var stime_onscoviddeath			"Survival time (date); outcome ONS COVID death"
label var stime_ons_noncoviddeath		"Survival time (date); outcome ONS non-COVID death"

* binary indicators
label var suspected 				"outcome suspected case"
label var confirmed 				"outcome confirmed case"
label var tested 					"outcome SGSS test performed"
label var positivetest 				"outcome SGSS test positive"
label var ae 						"outcome A&E Attendance"
label var icu 						"outcome ICU Admission"
*label var ventilation				"outcome ICU Ventilation"
label var cpnsdeath 				"outcome CPNS death"
label var onsdeath 					"outcome ONS death any cause"
label var onscoviddeath				"outcome ONS COVID death"
label var ons_noncoviddeath			"outcome ONS non-COVID death"

/* TIDY DATA==================================================================*/
*  Drop variables that are not needed (those not labelled)
ds, not(varlabel)
drop `r(varlist)'
	

/* APPLY INCLUSION/EXCLUIONS==================================================*/ 



noi di "DROP AGE >110:"
drop if age > 110 & age != .

noi di "DROP IF DIED BEFORE INDEX"
drop if onsdeath_date <= date("$indexdate", "DMY")

noi di "DROP IF OUTCOMES OCCUR BEFORE INDEX"

local p"suspected confirmed tested positivetest ae icu ventilation cpnsdeath onsdeath onscoviddeath ons_noncoviddeath" 
foreach i of local p {
	cap drop if `i'_date <= date("$indexdate", "DMY") 
}
	
***************
*  Save data  *
***************
sort patient_id
save "$Tempdir/analysis_dataset.dta", replace

**save a version set on each outcome
local p"suspected confirmed tested positivetest ae icu cpnsdeath onsdeath onscoviddeath ons_noncoviddeath" //ventilation
foreach i of local p {
	use "$Tempdir/analysis_dataset.dta", clear

	stset stime_`i', fail(`i') 				///
	id(patient_id) enter(enter_date) origin(enter_date)
	save "$Tempdir/analysis_dataset_STSET_`i'.dta", replace
}	
	
* Close log file 
log close

