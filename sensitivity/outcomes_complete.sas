/*********************************************************************************************/
title1 'Highly Complete Contracts';

* Author: PF;
* Purpose: Run monthly outcomes limited to the complete contracts;
* Input: ffs_mocd2, ma_mocd2, &outlib..benecomplete1518;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

proc sql;
	create table &tempwork..ma_mocd2_complete as
	select x.*, y.complete2015, y.complete2016, y.complete2017, y.complete2018
	from &outlib..ma_mocd2 as x left join &outlib..benecomplete1518 as y
	on x.bene_id=y.bene_id;
quit;

data &tempwork..ma_mocd2_complete;
	set &tempwork..ma_mocd2_complete;

	if year(death_date)=2017 then complete=max(of complete2015-complete2017);
	else if year(death_date)>2017 or death_date=. then complete=max(of complete2015-complete2018);

	if complete;
run;

%macro exportmocdc(data);
proc export data=&tempwork..&data._c
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/monthlyoutcomes_cd1518_complete.xlsx"
	dbms=xlsx
	replace;
	sheet="&data._c";
run;
%mend;

%macro outcomesc(samp);
proc means data=&tempwork..&samp._mocd2_complete noprint nway;
	where incplwd=1;
	class mosfrmPLWD;
	var awv ipcount opcount opcountvd fl_awv fl_ip fl_op fl_opvd;
	output out=&tempwork..&samp._plwdmo_statscd_c (drop=_type_ rename=_freq_=N) mean()= sum()= lclm()= uclm()= / autoname;
run;
%exportmocdc(&samp._plwdmo_statscd);


proc means data=&tempwork..&samp._mocd2_complete noprint nway;
	where incarthglau=1;
	class mosfrmarthglau;
	var awv ipcount opcount opcountvd fl_awv fl_ip fl_op fl_opvd ;
	output out=&tempwork..&samp._arthglaumo_statscd_c (drop=_type_ rename=_freq_=N) mean()= sum()= lclm()= uclm()= /autoname;
run;
%exportmocdc(&samp._arthglaumo_statscd);

%mend;

%outcomesc(ma);

/* Each month has to be age-adjusted to match FFS month */
%macro ageadjmocdc(inc);
proc freq data=&outlib..ffs_mocd2 noprint;
	where inc&inc.=1;
	table mosfrm&inc.*agemo / out=&tempwork..agedist_ffsmo&inc.cd (drop=count rename=pct_row=pct_ffs) outpct;
run;

proc freq data=&tempwork..ma_mocd2_complete noprint;
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

proc sort data=&tempwork..ma_mocd2_complete; by mosfrm&inc. agemo; run;

data ma_mocd2_&inc.wc;
	merge &tempwork..ma_mocd2_complete (in=a) 
		  &tempwork..age_weightmo&inc.cd (in=b);
	by mosfrm&inc. agemo;
	if a;

	array count_ [*] awv ipcount opcount ;
	array count&inc.w [*] awvcount&inc.w ipcount&inc.w opcount&inc.w ;

	if inc&inc.=1 then do i=1 to dim(count_);
		count&inc.w[i]=count_[i]*weighrate&inc.;
	end;

run;

proc univariate data=ma_mocd2_&inc.wc noprint outtable=&tempwork..weight&inc.ckcd;
	where inc&inc.=1;
	var weight&inc.;
run;

proc means data=ma_mocd2_&inc.wc noprint nway;
	where inc&inc.=1;
	weight weight&inc.;
	class mosfrm&inc.;
	var fl_awv fl_ip fl_op;
	output out=&tempwork..mamocd_&inc.w_fl (drop=_type_ rename=_freq_=n) mean()= sum()= lclm()= uclm()= / autoname;
run;
%exportmocdc(mamocd_&inc.w_fl);

proc means data=ma_mocd2_&inc.wc noprint nway;
	where inc&inc.=1;
	class mosfrm&inc.;
	var awvcount&inc.w ipcount&inc.w opcount&inc.w;
	output out=&tempwork..mamocd_&inc.w_count (drop=_type_ rename=_freq_=n) mean()= sum()= lclm()= uclm()=  / autoname;
run;
%exportmocdc(mamocd_&inc.w_count);
%mend;

%ageadjmocdc(plwd);
%ageadjmocdc(arthglau);
