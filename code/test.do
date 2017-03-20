clear all
mac drop _all
do code/setup_ado.do

//standard tests
//do code/usage.do
//These below are extra tests aside from usage.do

version 12
set scheme s2mono
set more off
mata: mata clear
mata: mata set matafavor speed
parallel setclusters 2, force

log close _all
log using "test.log", replace


//un-evenly spaced panel in parallel
if 1{
sysuse smoking, clear
tsset state year
drop if year==1986 | year==1991 
gen byte D = (state==3 & year>=1989) | (state==7 & year>=1988) //Georgia
synth_runner cigsale beer(1984 1985 1987) lnincome(1972(1)1985 1987) retprice age15to24, d(D) ///
	trends training_propr(`=13/17') max_lead(5) parallel
ereturn list
}

//deterministic - in parallel - with programs
if 1{
cap program drop _drop_units
program _drop_units
	args tunit
	
	if `tunit'==39 qui drop if inlist(state,21,38)
	if `tunit'==3 qui drop if state==21
end
cap program drop _gen_predictors
program _gen_predictors, rclass
	args year
	return local predictors "beer(`=`year'-4'(1)`=`year'-1') lnincome(`=`year'-4'(1)`=`year'-1')"
end
//with t in {1988,1989} we consistently have at least 12 pre-t years
cap program drop my_xperiod
program my_xperiod, rclass
	args tyear
	return local xperiod "`=`tyear'-12'(1)`=`tyear'-1'"
end
cap program drop my_mspeperiod
program my_mspeperiod, rclass
	args tyear
	return local mspeperiod "`=`tyear'-12'(1)`=`tyear'-1'"
end
sysuse smoking, clear
tsset state year
gen byte D = (state==3 & year>=1989) | (state==7 & year>=1988) //Georgia
synth_runner cigsale retprice age15to24, d(D) pred_prog(_gen_predictors) ///
	trends training_propr(`=13/17') max_lead(5) drop_units_prog(_drop_units) ///
	xperiod_prog(my_xperiod) mspeperiod_prog(my_mspeperiod) parallel deterministicoutput
synth_runner cigsale retprice age15to24, d(D) pred_prog(_gen_predictors) ///
	trends training_propr(`=13/17') drop_units_prog(_drop_units) ///
	xperiod_prog(my_xperiod) mspeperiod_prog(my_mspeperiod) parallel deterministicoutput noenforce_const_pre_length
ereturn list
}

//Test that failures are handled properly
if 1{
sysuse smoking, clear
tsset state year
gen byte D = (state==3 & year>=1989) | (state==7 & year>=1988) //Georgia

cap program drop _bad_control
program _bad_control
	args tunit
	
	if `tunit'==39 qui drop if state!=39
end

cap program drop _bad_treated
program _bad_treated
	args tunit
	
	if `tunit'==3 qui drop if state!=3
end

//Should error when can't do treatment
cap noi synth_runner cigsale beer(1984(1)1988) retprice age15to24, d(D) drop_units_prog(_bad_treated) 
_assert _rc==111

//Should be fine with an error in donors
synth_runner cigsale beer(1984(1)1988) retprice age15to24, d(D) drop_units_prog(_bad_control) 
mat li e(failed_opt_targets)
//should see (1988, 39 \ 1989, 39)
}

cap noisily log close
