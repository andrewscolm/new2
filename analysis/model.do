import delimited `c(pwd)'/output/input.csv, clear


*set filepaths
global Projectdir `c(pwd)'
global Dodir "$Projectdir/analysis" 
di "$Dodir"
global Outdir "$Projectdir/output" 
di "$Outdir"
global Logdir "$Outdir/log"
di "$Logdir"
global Tempdir "$Outdir/tempdata" 
di "$Tempdir"
global Tabfigdir "$Outdir/tabfig" 
di "$Tabfigdir"

cd  "`c(pwd)'/analysis"

adopath + "$Dodir"
sysdir
sysdir set PLUS "$Dodir"

cd  "$Projectdir"

***********************HOUSE-KEEPING*******************************************
* Create directories required 

capture mkdir "$Outdir/log"
capture mkdir "$Outdir/tempdata"
capture mkdir "$Outdir/tabfig"

* Set globals that will print in programs and direct output
global outdir  	  "$Outdir" 
global logdir     "$Logdir"
global tempdir    "$Tempdir"


* Set globals for  outcomes
global outcomes "suspected confirmed  tested positivetest ae icu cpnsdeath onsdeath onscoviddeath ons_noncoviddeath severe"

global outcomes2 "ae icu cpnsdeath onsdeath onscoviddeath ons_noncoviddeath severe"

/**********************
Data cleaning
**********************/

*Create analysis dataset
do "$Dodir/01_eth_cr_analysis_dataset.do"

*Checks 
do "$Dodir/02_eth_an_data_checks.do"

*  Descriptives
do "$Dodir/03_eth_an_descriptive_tables.do"
*do "$Dodir/04_eth_an_descriptive_plots.do"  - works locally and on server  

/**********************
Primary Objectives
**********************/

*Table 1 baseline characteristics
do "$Dodir/05a_eth_table1_descriptives_eth16.do"
do "$Dodir/05b_eth_table1_descriptives_eth5.do"

*Table 2: multivariable analysis - complete case 
do "$Dodir/06a_eth_an_multivariable_eth16.do" 
do "$Dodir/06b_eth_an_multivariable_eth5.do"

*multivariable analysis - imputed ethnicity
do "$Dodir/08a_eth_an_multivariable_eth16_mi.do"
do "$Dodir/08b_eth_an_multivariable_eth5_mi.do"

*Forest plots for complete case analysis and MI
do "$Dodir/07_eth_cr_forestplots.do"

*Table 3: Odds of receiving ventilation - in those admitted to ICU
do "$Dodir/09a_eth_an_ventilation_eth16"
do "$Dodir/09b_eth_an_ventilation_eth5"

*Table 4: Rates - crude, age, and age-sex stratified
do "$Dodir/10a_eth_an_rates_eth16"
do "$Dodir/10b_eth_an_rates_eth5"

*Table 5: Odds of testing positive amongst those with SGSS testing data
do "$Dodir/11a_eth_an_testedpop_eth16"
do "$Dodir/11b_eth_an_testedpop_eth5"

*Table 6: seconday care outcomes amongs those with evidence of infection prior to hospitalisation (may be weird as many people tested in hospital)
do "$Dodir/12a_eth_an_infected_eth16"
do "$Dodir/12b_eth_an_infected_eth5"


/**********************
Secondary Objectives
**********************/
*Household size
do "$Dodir/13a_eth_an_household_eth16"
do "$Dodir/13b_eth_an_household_eth5"

*By calendar period

*Diabetes

*Hypertension
