/*********************************************************************************************/
title1 'MA/FFS Pilot';

* Author: PF;
* Purpose: Run monthly outcomes limited to the complete contracts;
* Input: ffs_mocd2, ma_mocd2, &tempwork..ffs_obs1518, &tempwork..ma_obs1518;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

options obs=max;

* Merge observation stays output;
proc sort data=&tempwork..ffs_obs1518; by bene_id year mo; run;

data ffs_mocd2_obs;
	merge &outlib..ffs_mocd2 (in=a) &tempwork..ffs_obs1518 (in=b);
	by bene_id year mo;
	if a;
	if obs1=. then obs1=0;
	if obs2=. then obs2=0;
	fl_obs1=(obs1>0);
	fl_obs2=(obs2>0);
run;

proc sort data=&outlib..ma_mocd2; by bene_id year mo; run;
proc sort data=&tempwork..ma_obs1518; by bene_id year mo; run;

data ma_mocd2_obs;
	merge &outlib..ma_mocd2 (in=a) &tempwork..ma_obs1518 (in=b);
	by bene_id year mo;
	if a;
	if obs1=. then obs1=0;
	if obs2=. then obs2=0;
	fl_obs1=(obs1>0);
	fl_obs2=(obs2>0);
run;

%macro exportmoobs(data);
proc export data=&tempwork..&data.
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/monthlyoutcomes_cd1518_obs.xlsx"
	dbms=xlsx
	replace;
	sheet="&data.";
run;
%mend;

%macro outcomeobs(samp);

proc means data=&samp._mocd2_obs noprint nway;
	where incplwd=1;
	class mosfrmPLWD;
	var obs1 obs2 fl_obs1 fl_obs2;
	output out=&tempwork..&samp._plwdmo_statscd_obs (drop=_type_ rename=_freq_=N) mean()= sum()= lclm()= uclm()= / autoname;
run;
%exportmoobs(&samp._plwdmo_statscd_obs);


proc means data=&samp._mocd2_obs noprint nway;
	where incarthglau=1;
	class mosfrmarthglau;
	var obs1 obs2 fl_obs1 fl_obs2;
	output out=&tempwork..&samp._arthglaumo_statscd_obs (drop=_type_ rename=_freq_=N) mean()= sum()= lclm()= uclm()= /autoname;
run;
%exportmoobs(&samp._arthglaumo_statscd_obs);

%mend;

%outcomeobs(ffs);
%outcomeobs(ma);

/* Each month has to be age-adjusted to match FFS month */
%macro ageadjmoobs(inc);

proc freq data=ffs_mocd2_obs noprint;
	where inc&inc.=1;
	table mosfrm&inc.*agemo / out=&tempwork..agedist_ffsmo&inc.cd (drop=count rename=pct_row=pct_ffs) outpct;
run;

proc freq data=ma_mocd2_obs noprint;
	where inc&inc.=1;
	table mosfrm&inc.*agemo / out=&tempwork..agedist_mamo&inc.cd (drop=pct_col rename=pct_row=pct_ma) outpct;
run;

data &tempwork..age_weightmo&inc.cd;
	merge &tempwork..agedist_ffsmo&inc.cd (in=a) &tempwork..agedist_mamo&inc.cd (in=b);
	by mosfrm&inc. agemo;
	weight&inc.=(pct_ffs/100)/count;
	oldweight&inc.=(pct_ma/100)/count;
	weighrate&inc.=weight&inc./oldweight&inc.;
run;

proc sort data=ma_mocd2_obs; by mosfrm&inc. agemo; run;

data ma_mocd2_&inc.w_obs;
	merge ma_mocd2_obs (in=a) 
		  &tempwork..age_weightmo&inc.cd (in=b);
	by mosfrm&inc. agemo;
	if a;

	array count_ [*] obs1 obs2 ;
	array count&inc.w [*] obs1&inc.w obs2&inc.w ;

	if inc&inc.=1 then do i=1 to dim(count_);
		count&inc.w[i]=count_[i]*weighrate&inc.;
	end;

run;

proc univariate data=ma_mocd2_&inc.w_obs noprint outtable=&tempwork..weight&inc.ckc_obs;
	where inc&inc.=1;
	var weight&inc.;
run;

proc means data=ma_mocd2_&inc.w_obs noprint nway;
	where inc&inc.=1;
	weight weight&inc.;
	class mosfrm&inc.;
	var fl_obs1 fl_obs2;
	output out=&tempwork..mamocd_&inc.w_fl_obs (drop=_type_ rename=_freq_=n) mean()= sum()= lclm()= uclm()= / autoname;
run;
%exportmoobs(mamocd_&inc.w_fl_obs);

proc means data=ma_mocd2_&inc.w_obs noprint nway;
	where inc&inc.=1;
	class mosfrm&inc.;
	var obs1&inc.w obs2&inc.w;
	output out=&tempwork..mamocd_&inc.w_count_obs (drop=_type_ rename=_freq_=n) mean()= sum()= lclm()= uclm()=  / autoname;
run;
%exportmoobs(mamocd_&inc.w_count_obs);
%mend;

%ageadjmoobs(plwd);
%ageadjmoobs(arthglau);
