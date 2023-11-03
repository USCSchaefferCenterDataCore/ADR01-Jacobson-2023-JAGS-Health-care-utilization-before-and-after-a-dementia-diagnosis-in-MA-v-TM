/*********************************************************************************************/
title1 'Highly Complete Contracts';

* Author: PF;
* Purpose: Add diagnosed in hospital as a covariate;
* Input: plwd_mortc, arthglauc, mortalitydddc, maffs.ipincdx_bene;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

/* DD */
data plwd_mortc_loc;
	merge plwd_mortc (in=a) maffs.ipincdx_bene (in=b keep=bene_id ipincdx);
	by bene_id;
	if a;
run;

%let cond=plwd;
%let out=loc_c;
%let cov=dualmo lismo cc_: ipincdx;
ods output parameterestimates=&tempwork..&cond._&out.est;
ods output oddsratios=&tempwork..&cond._&out.or;
proc logistic data=&cond._mortc_loc;
	class female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs &cov. / desc param=reference;
	model surv=female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs &cov.;
run;

proc export data=&tempwork..&cond._&out.est
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/models_mortality_c.xlsx"
	dbms=xlsx
	replace;
	sheet="&cond._&out.est";
run;

proc export data=&tempwork..&cond._&out.or
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/models_mortality_c.xlsx"
	dbms=xlsx
	replace;
	sheet="&cond._&out.or";
run;

/* DDD */
proc sort data=mortalitydddc; by bene_id; run;

data mortalitydddc_loc;
	merge mortalitydddc (in=a) &outlib..ipincdx_bene (in=b keep=bene_id ipincdx);
	by bene_id;
	if a;
run;

* full sample;
%let out=loc_c;
%let cov=dualmo lismo cc_: ipincdx;
ods output parameterestimates=&tempwork..mortddd_&out.est;
ods output oddsratios=&tempwork..mortddd_&out.or;
proc logistic data=mortalitydddc_loc;
	class female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs plwd plwdffs &cov. / desc param=reference;
	model surv=female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs plwd plwdffs &cov.;
run;

proc export data=&tempwork..mortddd_&out.est
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality_c.xlsx"
	dbms=xlsx
	replace;
	sheet="mortddd_&out.est";
run;

proc export data=&tempwork..mortddd_&out.or
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality_c.xlsx"
	dbms=xlsx
	replace;
	sheet="mortddd_&out.or";
run;
