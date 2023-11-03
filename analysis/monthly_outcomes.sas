/*********************************************************************************************/
title1 'MA/FFS Pilot';

* Author: PF;
* Purpose: Create monthly outcomes for AWV, inpatient, and outpatient visits
	- Create a month for each beneficiary from start of 2015 to death
	- Merge to outcomes, fill with 0 
	- Set number of month relative to month of DX (PLWD, MCI, Arthritis or Glaucoma)
	- Plot age-adjusted percent with outcome
	- Plot age-adjusted number of visits per 100k;
* Input: sample data and bene-monthly outcomes;
* Output: Age-adjusted percent with outcome, age-adjusted number of visits per 100k;

options compress=yes nocenter ls=150 ps=200 errors=5 errorcheck=strict mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

options obs=max;

%macro exportmocd(data);
proc export data=&tempwork..&data.
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/monthlyoutcomes_cd1518_ci.xlsx"
	dbms=xlsx
	replace;
	sheet="&data.";
run;
%mend;

* Create a month for each beneficiary from start of 2015 to death;
%macro monthly(samp);
data &tempwork..&samp._mocd;
	set &tempwork..&samp._samp_2yrwsh1yrv (keep=bene_id death_date inc: first_adrddx first_arthglau race_d: female birth_date age_beg2017 cc_:);
	if year(death_date)=2016 then deathmo16=month(death_date);
	if year(death_date)=2017 then deathmo17=month(death_date);
	if year(death_date)=2018 then deathmo18=month(death_date);
	do mo=1 to 12;
		year=2015;
		month=mo;
		agemo=intck('year',birth_date,mdy(mo,1,2015),'c');
		agemo_lt75=(agemo<75);
		agemo_7584=(75<=agemo<=84);
		agemo_ge85=(agemo>=85);
		output;
	end;
	if death_date=. or death_date>=mdy(1,1,2016) then do mo=1 to min(deathmo16,12);
		year=2016;
		month=mo;
		agemo=intck('year',birth_date,mdy(mo,1,2016),'c');
		agemo_lt75=(agemo<75);
		agemo_7584=(75<=agemo<=84);
		agemo_ge85=(agemo>=85);
		output;
	end;
	if  death_date=. or death_date>=mdy(1,1,2017) then do mo=1 to min(deathmo17,12);
		year=2017;
		month=mo;
		agemo=intck('year',birth_date,mdy(mo,1,2017),'c');
		agemo_lt75=(agemo<75);
		agemo_7584=(75<=agemo<=84);
		agemo_ge85=(agemo>=85);
		output;
	end;
	if  death_date=. or death_date>=mdy(1,1,2018) then do mo=1 to min(deathmo18,12);
		year=2018;
		month=mo;
		agemo=intck('year',birth_date,mdy(mo,1,2018),'c');
		agemo_lt75=(agemo<75);
		agemo_7584=(75<=agemo<=84);
		agemo_ge85=(agemo>=85);
		output;
	end;		
run;

proc sort data=&tempwork..&samp._mocd; by bene_id year month; run;

%mend;

%monthly(ffs);
%monthly(ma);

* Merge to outcomes and dual/lis month;
data &tempwork..duallismo1518;
	set mbsf.mbsf_abcd_2015 (in=a keep=bene_id MDCR_ENTLMT_BUYIN_IND: CST_SHR_GRP_CD:)
		mbsf.mbsf_abcd_2016 (in=b keep=bene_id MDCR_ENTLMT_BUYIN_IND: CST_SHR_GRP_CD:)
		mbsf.mbsf_abcd_2017 (in=c keep=bene_id MDCR_ENTLMT_BUYIN_IND: CST_SHR_GRP_CD:)
		mbsf.mbsf_abcd_2018 (in=d keep=bene_id MDCR_ENTLMT_BUYIN_IND: CST_SHR_GRP_CD:);
	by bene_id;
	array enr [*] mdcr_entlmt_buyin_ind_01-mdcr_entlmt_buyin_ind_12;
	array cst [*] cst_shr_grp_cd_01-cst_shr_grp_cd_12;
	if a then do mo=1 to 12;
		year=2015;
		month=mo;
		dualmo=(enr[mo] in("A","B","C"));
		lismo=(cst[mo] in("04","05","06","07","08"));
		output;
	end;
	if b then do mo=1 to 12;
		year=2016;
		month=mo;
		dualmo=(enr[mo] in("A","B","C"));
		lismo=(cst[mo] in("04","05","06","07","08"));
		output;
	end;
	if c then do mo=1 to 12;
		year=2017;
		month=mo;
		dualmo=(enr[mo] in("A","B","C"));
		lismo=(cst[mo] in("04","05","06","07","08"));
		output;
	end;
	if d then do mo=1 to 12;
		year=2018;
		month=mo;
		dualmo=(enr[mo] in("A","B","C"));
		lismo=(cst[mo] in("04","05","06","07","08"));
		output;
	end;
run;

proc sort data= &tempwork..duallismo1518; by bene_id year month; run;

* Merge to outcomes, filling all missing variables with 0;
%macro mergecd(samp,maxyr=);
proc sort data=&outlib..&samp._bene_preventiveprcdr15&maxyr.; by bene_id year month; run;
proc sort data=&outlib..&samp._bene_ip15&maxyr.; by bene_id year month; run;
proc sort data=&outlib..&samp._bene_op15&maxyr.; by bene_id year month; run;
proc sort data=&outlib..&samp._bene_op_visitdays; by bene_id year month; run;

data &tempwork..&samp._mocd1;
	merge &tempwork..&samp._mocd (in=a) 
		  &tempwork..duallismo1518 (in=b keep=bene_id year month dualmo lismo)
		  &outlib..&samp._bene_preventiveprcdr15&maxyr. (in=c)
		  &outlib..&samp._bene_ip15&maxyr. (in=d)
		  &outlib..&samp._bene_op15&maxyr. (in=e)
		  &outlib..&samp._bene_op_visitdays (in=f rename=(opcount=opcountvd));
	by bene_id year month;

	array out [*] awv ipcount opcount opcountvd dualmo lismo;
	do i=1 to dim(out);
		if out[i]=. then out[i]=0;
	end;

	array fl_out [*] fl_awv fl_ip fl_op fl_opvd;
	do i=1 to dim(fl_out);
		fl_out[i]=0;
		if out[i]>0 then fl_out[i]=1;
	end;

	* checking merge;
	&samp.=a;
	ses=b;
	prev=c;
	ip=d;
	op=e;

	afterdeath=0;
	if a=0 and max(fl_awv,fl_ip,fl_op)=1 then afterdeath=1;
run;

* Check merge and for outcomes after death;
proc freq data=&tempwork..&samp._mocd1;
	table &samp.*(prev ip op) afterdeath;
run;

* Calculating rates of use;
data &tempwork..&samp._mocd2;
	set &tempwork..&samp._mocd1 (where=(&samp.=1));
	drop &samp. ses prev ip op;

	* Getting time since first dx;
	if incplwd=1 then mosfrmPLWD=intck('month',first_adrddx,mdy(month,1,year),'d');
	if incarthglau=1 then mosfrmarthglau=intck('month',first_arthglau,mdy(month,1,year),'d');

	* Getting three year age bands;
	array age3y [*] age3y1-age3y8;

	do i=1 to dim(age3y);
		age3y[i]=0;
		if sum(3*i,66,-3)<agemo<=sum(3*i,66) then do;
			age3y[i]=1;
			agecat=i;
		end;
	end;
	age3y9=0;
	if agemo>90 then do;
		age3y9=1;
		agecat=9;
	end;

run; 

/* create perm */
data &outlib..&samp._mocd2;
	set &tempwork..&samp._mocd2;
run; 

%mend;

%mergecd(ffs,maxyr=18);
%mergecd(arthglau,maxyr=18);

%macro unadjoutcomes(samp);
proc means data=&outlib..&samp._mocd2 noprint nway;
	where incplwd=1;
	class mosfrmPLWD;
	var awv ipcount opcount opcountvd fl_awv fl_ip fl_op fl_opvd;
	output out=&tempwork..&samp._plwdmo_statscdci (drop=_type_ rename=_freq_=N) mean()= sum()= lclm()= uclm()= / autoname;
run;
%exportmocd(&samp._plwdmo_statscdci);


proc means data=&outlib..&samp._mocd2 noprint nway;
	where incarthglau=1;
	class mosfrmarthglau;
	var awv ipcount opcount opcountvd fl_awv fl_ip fl_op fl_opvd ;
	output out=&tempwork..&samp._arthglaumo_statscdci (drop=_type_ rename=_freq_=N) mean()= sum()= lclm()= uclm()= /autoname;
run;
%exportmocd(&samp._arthglaumo_statscdci);

%mend;

%unadjoutcomes(ffs);
%unadjoutcomes(ma);

* Unadjusted outcomes by race;
%macro unadjoutcomessub(samp,subgroup,val,out);

proc means data=&outlib..&samp._mocd2 noprint nway;
	where incplwd=1 and &subgroup.=&val.;
	class mosfrmPLWD;
	var awv ipcount opcount opcountvd fl_awv fl_ip fl_op fl_opvd;
	output out=&tempwork..&samp._plwdmo_statscdci&out. (drop=_type_ rename=_freq_=N) mean()= sum()= lclm()= uclm()= / autoname;
run;
%exportmocd(&samp._plwdmo_statscdci&out.); 


proc means data=&outlib..&samp._mocd2 noprint nway;
	where incarthglau=1 and &subgroup.=&val.;
	class mosfrmarthglau;
	var awv ipcount opcount opcountvd fl_awv fl_ip fl_op fl_opvd ;
	output out=&tempwork..&samp._arthglaumo_statscdci&out. (drop=_type_ rename=_freq_=N) mean()= sum()= lclm()= uclm()= /autoname;
run;
%exportmocd(&samp._arthglaumo_statscdci&out.);

%mend;

%unadjoutcomessub(ffs,race_dw,1,w);
%unadjoutcomessub(ffs,race_db,1,b);
%unadjoutcomessub(ffs,race_dh,1,h);
%unadjoutcomessub(ffs,race_dn,1,n);
%unadjoutcomessub(ffs,race_do,1,o);
%unadjoutcomessub(ffs,race_da,1,a);
%unadjoutcomessub(ffs,female,1,f);
%unadjoutcomessub(ffs,female,0,m);
%unadjoutcomessub(arthglau,race_dw,1,w);
%unadjoutcomessub(arthglau,race_db,1,b);
%unadjoutcomessub(arthglau,race_dh,1,h);
%unadjoutcomessub(arthglau,race_dn,1,n);
%unadjoutcomessub(arthglau,race_do,1,o);
%unadjoutcomessub(arthglau,race_dn,1,a);
%unadjoutcomessub(arthglau,female,1,f);
%unadjoutcomessub(arthglau,female,0,m);

/* Each month has to be age-adjusted to match FFS month */
%macro ageadjmocd(inc);
proc freq data=&outlib..ffs_mocd2 noprint;
	where inc&inc.=1;
	table mosfrm&inc.*agemo / out=&tempwork..agedist_ffsmo&inc.cd (drop=count rename=pct_row=pct_ffs) outpct;
run;

proc freq data=&outlib..ma_mocd2 noprint;
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

proc sort data=&outlib..ma_mocd2; by mosfrm&inc. agemo; run;

data &tempwork..ma_mocd2_&inc.w;
	merge &outlib..ma_mocd2 (in=a) 
		  &tempwork..age_weightmo&inc.cd (in=b);
	by mosfrm&inc. agemo;
	if a;

	array count_ [*] awv ipcount opcount ;
	array count&inc.w [*] awvcount&inc.w ipcount&inc.w opcount&inc.w ;

	if inc&inc.=1 then do i=1 to dim(count_);
		count&inc.w[i]=count_[i]*weighrate&inc.;
	end;

run;

proc univariate data=&tempwork..ma_mocd2_&inc.w noprint outtable=&tempwork..weight&inc.ckcd;
	where inc&inc.=1;
	var weight&inc.;
run;

proc means data=&tempwork..ma_mocd2_&inc.w noprint nway;
	where inc&inc.=1;
	weight weight&inc.;
	class mosfrm&inc.;
	var fl_awv fl_ip fl_op;
	output out=&tempwork..mamocd_&inc.w_flci (drop=_type_ rename=_freq_=n) mean()= sum()= lclm()= uclm()= / autoname;
run;
%exportmocd(mamocd_&inc.w_flci);

proc means data=&tempwork..ma_mocd2_&inc.w noprint nway;
	where inc&inc.=1;
	class mosfrm&inc.;
	var awvcount&inc.w ipcount&inc.w opcount&inc.w;
	output out=&tempwork..mamocd_&inc.w_countci (drop=_type_ rename=_freq_=n) mean()= sum()= lclm()= uclm()= / autoname;
run;
%exportmocd(mamocd_&inc.w_countci);
%mend;

%ageadjmocd(plwd);
%ageadjmocd(arthglau);

%macro weightrace(inc,subgroup,val,out);
proc freq data=&outlib..ffs_mocd2 noprint;
	where inc&inc.=1 and &subgroup.=&val.;
	table mosfrm&inc.*agemo / out=&tempwork..agedist_ffsmo&inc.cd&out. (drop=count rename=pct_row=pct_ffs) outpct;
run;

proc freq data=&outlib..ma_mocd2 noprint;
	where inc&inc.=1 and &subgroup.=&val.;
	table mosfrm&inc.*agemo / out=&tempwork..agedist_mamo&inc.cd&out. (drop=pct_col rename=pct_row=pct_ma) outpct;
run;

data &tempwork..age_weightmo&inc.cd&out.;
	merge &tempwork..agedist_ffsmo&inc.cd&out. (in=a) &tempwork..agedist_mamo&inc.cd&out. (in=b);
	by mosfrm&inc. agemo;
	weight&inc.&out.=(pct_ffs/100)/count;
	oldweight&inc.&out.=(pct_ma/100)/count;
	weighrate&inc.&out.=weight&inc.&out./oldweight&inc.&out.;
run;
%mend;

%weightrace(plwd,race_dw,1,w);
%weightrace(plwd,race_db,1,b);
%weightrace(plwd,race_dh,1,h);
%weightrace(plwd,race_dn,1,n);
%weightrace(plwd,race_do,1,o);
%weightrace(plwd,race_da,1,a);
%weightrace(plwd,female,1,f);
%weightrace(plwd,female,0,m);
%weightrace(arthglau,race_dw,1,w);
%weightrace(arthglau,race_db,1,b);
%weightrace(arthglau,race_dh,1,h);
%weightrace(arthglau,race_dn,1,n);
%weightrace(arthglau,race_do,1,o);
%weightrace(arthglau,race_dn,1,a);
%weightrace(arthglau,female,1,f);
%weightrace(arthglau,female,0,m);

proc sort data=&outlib..ma_mocd2; by mosfrmplwd agemo; run;

data &tempwork..ma_mocd2_plwdw;
	merge &outlib..ma_mocd2 (in=a) 
		  &tempwork..age_weightmoplwdcdw (in=b)
		&tempwork..age_weightmoplwdcdb (in=b)
		&tempwork..age_weightmoplwdcdh (in=b)
		&tempwork..age_weightmoplwdcda (in=b)
		&tempwork..age_weightmoplwdcdn (in=b)
		&tempwork..age_weightmoplwdcdo (in=b)
		&tempwork..age_weightmoplwdcdf (in=b)
		&tempwork..age_weightmoplwdcdm (in=b);
	by mosfrmplwd agemo;
	if a;

	array count_ [*] awv ipcount opcount ;
	array countplwdww [*] awvcountplwdww ipcountplwdww opcountplwdww ;
	array countplwdwb [*] awvcountplwdwb ipcountplwdwb opcountplwdwb ;
	array countplwdwh [*] awvcountplwdwh ipcountplwdwh opcountplwdwh ;
	array countplwdwa [*] awvcountplwdwa ipcountplwdwa opcountplwdwa ;
	array countplwdwn [*] awvcountplwdwn ipcountplwdwn opcountplwdwn ;
	array countplwdwo [*] awvcountplwdwo ipcountplwdwo opcountplwdwo ;
	array countplwdwf [*] awvcountplwdwf ipcountplwdwf opcountplwdwf ;
	array countplwdwm [*] awvcountplwdwm ipcountplwdwm opcountplwdwm ;

	if incplwd=1 then do i=1 to dim(count_);
		countplwdww[i]=count_[i]*weighrateplwdw;
		countplwdwb[i]=count_[i]*weighrateplwdb;
		countplwdwh[i]=count_[i]*weighrateplwdh;
		countplwdwa[i]=count_[i]*weighrateplwda;
		countplwdwn[i]=count_[i]*weighrateplwdn;
		countplwdwo[i]=count_[i]*weighrateplwdo;
		countplwdwf[i]=count_[i]*weighrateplwdf;
		countplwdwm[i]=count_[i]*weighrateplwdm;
	end;

run;

proc sort data=&outlib..ma_mocd2; by mosfrmarthglau agemo; run;

data &tempwork..ma_mocd2_arthglauw;
	merge &outlib..ma_mocd2 (in=a) 
		  &tempwork..age_weightmoarthglaucdw (in=b)
		&tempwork..age_weightmoarthglaucdb (in=b)
		&tempwork..age_weightmoarthglaucdh (in=b)
		&tempwork..age_weightmoarthglaucda (in=b)
		&tempwork..age_weightmoarthglaucdn (in=b)
		&tempwork..age_weightmoarthglaucdo (in=b)
		&tempwork..age_weightmoarthglaucdf (in=b)
		&tempwork..age_weightmoarthglaucdm (in=b);
	by mosfrmarthglau agemo;
	if a;

	array count_ [*] awv ipcount opcount ;
	array countarthglauww [*] awvcountarthglauww ipcountarthglauww opcountarthglauww ;
	array countarthglauwb [*] awvcountarthglauwb ipcountarthglauwb opcountarthglauwb ;
	array countarthglauwh [*] awvcountarthglauwh ipcountarthglauwh opcountarthglauwh ;
	array countarthglauwa [*] awvcountarthglauwa ipcountarthglauwa opcountarthglauwa ;
	array countarthglauwn [*] awvcountarthglauwn ipcountarthglauwn opcountarthglauwn ;
	array countarthglauwo [*] awvcountarthglauwo ipcountarthglauwo opcountarthglauwo ;
	array countarthglauwf [*] awvcountarthglauwf ipcountarthglauwf opcountarthglauwf ;
	array countarthglauwm [*] awvcountarthglauwm ipcountarthglauwm opcountarthglauwm ;

	if incarthglau=1 then do i=1 to dim(count_);
		countarthglauww[i]=count_[i]*weighratearthglauw;
		countarthglauwb[i]=count_[i]*weighratearthglaub;
		countarthglauwh[i]=count_[i]*weighratearthglauh;
		countarthglauwa[i]=count_[i]*weighratearthglaua;
		countarthglauwn[i]=count_[i]*weighratearthglaun;
		countarthglauwo[i]=count_[i]*weighratearthglauo;
		countarthglauwf[i]=count_[i]*weighratearthglauf;
		countarthglauwm[i]=count_[i]*weighratearthglaum;
	end;

run;

%macro ageadjmocdsub(inc,subgroup,val,out);
proc univariate data=&tempwork..ma_mocd2_&inc.w noprint outtable=&tempwork..weight&inc.ckcd;
	where inc&inc.=1;
	var weight&inc.&out.;
run;

proc means data=&tempwork..ma_mocd2_&inc.w noprint nway;
	where inc&inc.=1 and &subgroup.=&val.;
	weight weight&inc.&out.;
	class mosfrm&inc.;
	var fl_awv fl_ip fl_op;
	output out=&tempwork..mamocd_&inc.w_flci&out. (drop=_type_ rename=_freq_=n) mean()= sum()= lclm()= uclm()= / autoname;
run;
%exportmocd(mamocd_&inc.w_flci&out.);

proc means data=&tempwork..ma_mocd2_&inc.w noprint nway;
	where inc&inc.=1 and &subgroup.=&val.;
	class mosfrm&inc.;
	var awvcount&inc.w&out. ipcount&inc.w&out. opcount&inc.w&out.;
	output out=&tempwork..mamocd_&inc.w_countci&out. (drop=_type_ rename=_freq_=n) mean()= sum()= lclm()= uclm()= / autoname;
run;
%exportmocd(mamocd_&inc.w_countci&out.);
%mend;

%ageadjmocdsub(plwd,race_dw,1,w);
%ageadjmocdsub(plwd,race_db,1,b);
%ageadjmocdsub(plwd,race_dh,1,h);
%ageadjmocdsub(plwd,race_dn,1,n);
%ageadjmocdsub(plwd,race_da,1,a);
%ageadjmocdsub(plwd,race_do,1,o);
%ageadjmocdsub(plwd,female,1,f);
%ageadjmocdsub(plwd,female,0,m);

%ageadjmocdsub(arthglau,race_dw,1,w);
%ageadjmocdsub(arthglau,race_db,1,b);
%ageadjmocdsub(arthglau,race_dh,1,h);
%ageadjmocdsub(arthglau,race_dn,1,n);
%ageadjmocdsub(arthglau,race_da,1,a);
%ageadjmocdsub(arthglau,race_do,1,o);
%ageadjmocdsub(arthglau,female,1,f);
%ageadjmocdsub(arthglau,female,0,m);
