/*********************************************************************************************/
title1 'Exclude Non-SNPs';

* Author: PF;
* Purpose: Run models excluding SNPs;
* Input: ffsplwd_collapsed, maplwd_collapsed, ma_mocd2_nonsnp;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

/* Collapsing */

* Placeholder for FFS collapsed - right now 3/13 pulling from complete ;

proc means data=&tempwork..ma_mocd2_nonsnp noprint nway;
	where -12<=mosfrmplwd<=12;
	class mosfrmplwd year month;
	output out=maplwd_collapsednonsnp (drop=_type_ rename=_freq_=benecount) mean(female race_dw race_db race_dh race_da race_do race_dn age3y2-age3y9 dualmo lismo cc: fl_ip)=
	sum(opcount opcountvd)=;
run;

proc means data=&tempwork..ma_mocd2_nonsnp noprint nway;
	where -12<=mosfrmarthglau<=12;
	class mosfrmarthglau year month;
	output out=maarthglau_collapsednonsnp (drop=_type_ rename=_freq_=benecount) mean(female race_dw race_db race_dh race_da race_do race_dn age3y2-age3y9 dualmo lismo cc: fl_ip)=
	sum(opcount opcountvd)=;
run;

/* Setting up for models */
data &tempwork..collapsednonsnp;
	set ffsplwd_collapsedc (in=a) ffsarthglau_collapsedc (in=b) maplwd_collapsednonsnp (in=c) maarthglau_collapsednonsnp (in=d);
	
	ffs=0;
	plwd=0;
	if a or b then ffs=1;
	if a or c then plwd=1;

	* Setting up dummies for calendar year and month;
	y_2015=(year=2015);
	y_2016=(year=2016);
	y_2017=(year=2017);
	y_2018=(year=2018);

	m_1=(month=1);
	m_2=(month=2);
	m_3=(month=3);
	m_4=(month=4);
	m_5=(month=5);
	m_6=(month=6);
	m_7=(month=7);
	m_8=(month=8);
	m_9=(month=9);
	m_10=(month=10);
	m_11=(month=11);
	m_12=(month=12);

	* Average op count per person;
	avgopcount=opcount/benecount;
	avgopcountvd=opcountvd/benecount;

	* Creating interaction terms for simple diff;
	array plwd_mfrm [*] plwd_mfrm1-plwd_mfrm25;
	array arthglau_mfrm [*] arthglau_mfrm1-arthglau_mfrm25;

	do i=1 to dim(plwd_mfrm);
		plwd_mfrm[i]=0;
		arthglau_mfrm[i]=0;
		if mosfrmplwd=i-13 then plwd_mfrm[i]=1;
		if mosfrmarthglau=i-13 then arthglau_mfrm[i]=1;
	end;

	array plwdint_mfrm [*] plwdint_mfrm1-plwdint_mfrm25;
	array arthglauint_mfrm [*] arthglauint_mfrm1-arthglauint_mfrm25;

	do i=1 to dim(plwd_mfrm);
		plwdint_mfrm[i]=plwd_mfrm[i]*ffs;
		arthglauint_mfrm[i]=arthglau_mfrm[i]*ffs;
	end;

	* Creating interaction terms for triple diff;

	* plwd*ffs;
	plwdffsint=plwd*ffs;
	*ffs indicator*relative-quarter (plwd and arthglau);
	array mfrm [*] mfrm1-mfrm25;
	array ffsint_mfrm [*] ffsint_mfrm1-ffsint_mfrm25;

	do i=1 to 25;
		mfrm[i]=max(plwd_mfrm[i],arthglau_mfrm[i]);
		ffsint_mfrm[i]=mfrm[i]*ffs;
	end;

	* plwd indicator*relative-quarter indicators*ffs indicator;
	array plwdffsint_mfrm [*] plwdffsint_mfrm1-plwdffsint_mfrm25;

	do i=1 to dim(plwdffsint_mfrm);
		plwdffsint_mfrm[i]=mfrm[i]*plwdffsint;
	end;

run;

proc freq data=&tempwork..collapsednonsnp;
	where mosfrmplwd ne .;
	table year*month / out=&tempwork..plwdqtrck;
	table mosfrmplwd*(plwd_mfrm:);
run;

proc freq data=&tempwork..collapsednonsnp;
	where mosfrmarthglau ne .;
	table year*month / out=&tempwork..arthglauqtrck;
	table mosfrmarthglau*(arthglau_mfrm:);
run;

proc univariate data=&tempwork..collapsednonsnp noprint outtable=&tempwork..collapsed_ck_bygrp;
	class plwd ffs;
run;

proc univariate data=&tempwork..collapsednonsnp noprint outtable=&tempwork..collapsed_ck;
run;

proc export data=&tempwork..collapsednonsnp (keep=benecount mosfrm: year month plwd ffs fl_ip opcount opcountvd avgopcount avgopcountvd)
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/models_collapsed_outcomes_nonsnp.xlsx"
	dbms=xlsx
	replace;
	sheet="outcomes_nonsnp";
run;

/* Simple diff and diff models */
%macro ddnonsnp(cond,dv,cov=,out=);
ods output parameterestimates=&tempwork..&cond._&dv.&out.nonsnp;
proc reg data=&tempwork..collapsednonsnp;
	weight benecount;
	where mosfrm&cond. ne .;
	model &dv.=female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs &cond._mfrm2-&cond._mfrm25 &cond.int_mfrm2-&cond.int_mfrm25 &cov. / clb;
run;

proc export data=&tempwork..&cond._&dv.&out.nonsnp
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/models_collapsed_ddnonsnp.xlsx"
	dbms=xlsx
	replace;
	sheet="&cond._&dv.&out.nonsnp";
run;
%mend;

* inpatient;
%ddnonsnp(plwd,fl_ip,out=base);
%ddnonsnp(plwd,fl_ip,cov=dualmo lismo, out=ses);
%ddnonsnp(plwd,fl_ip,cov=dualmo lismo cc:, out=cc);
%ddnonsnp(plwd,fl_ip,cov=dualmo lismo cc: y_2017 y_2018, out=yr);
%ddnonsnp(plwd,fl_ip,cov=dualmo lismo cc: y_2017 y_2018 m_2-m_12, out=cyc);

%ddnonsnp(arthglau,fl_ip,out=base);
%ddnonsnp(arthglau,fl_ip,cov=dualmo lismo, out=ses);
%ddnonsnp(arthglau,fl_ip,cov=dualmo lismo cc:, out=cc);
%ddnonsnp(arthglau,fl_ip,cov=dualmo lismo cc: y_2017 y_2018, out=yr);
%ddnonsnp(arthglau,fl_ip,cov=dualmo lismo cc: y_2017 y_2018 m_2-m_12, out=cyc);

* outpatient;
%ddnonsnp(plwd,avgopcount,out=base);
%ddnonsnp(plwd,avgopcount,cov=dualmo lismo, out=ses);
%ddnonsnp(plwd,avgopcount,cov=dualmo lismo cc:, out=cc);
%ddnonsnp(plwd,avgopcount,cov=dualmo lismo cc: y_2017 y_2018, out=yr);
%ddnonsnp(plwd,avgopcount,cov=dualmo lismo cc: y_2017 y_2018 m_2-m_12, out=cyc);

%ddnonsnp(arthglau,avgopcount,out=base);
%ddnonsnp(arthglau,avgopcount,cov=dualmo lismo, out=ses);
%ddnonsnp(arthglau,avgopcount,cov=dualmo lismo cc:, out=cc);
%ddnonsnp(arthglau,avgopcount,cov=dualmo lismo cc: y_2017 y_2018, out=yr);
%ddnonsnp(arthglau,avgopcount,cov=dualmo lismo cc: y_2017 y_2018 m_2-m_12, out=cyc);

* outpatient visit-days;
%dd(plwd,avgopcountvd,out=base);
%dd(plwd,avgopcountvd,cov=dualmo lismo, out=ses);
%dd(plwd,avgopcountvd,cov=dualmo lismo cc:, out=cc);
%dd(plwd,avgopcountvd,cov=dualmo lismo cc: y_2017 y_2018, out=yr);
%dd(plwd,avgopcountvd,cov=dualmo lismo cc: y_2017 y_2018 m_2-m_12, out=cyc);

%dd(arthglau,avgopcountvd,out=base);
%dd(arthglau,avgopcountvd,cov=dualmo lismo, out=ses);
%dd(arthglau,avgopcountvd,cov=dualmo lismo cc:, out=cc);
%dd(arthglau,avgopcountvd,cov=dualmo lismo cc: y_2017 y_2018, out=yr);
%dd(arthglau,avgopcountvd,cov=dualmo lismo cc: y_2017 y_2018 m_2-m_12, out=cyc);

/* Triple  diff */
%macro dddnonsnp(dv,cov=,out=);
ods output parameterestimates=&tempwork..&dv.&out.nonsnp;
proc reg data=&tempwork..collapsednonsnp;
	weight benecount;
	where mosfrmplwd ne . or mosfrmarthglau ne .;
	model &dv.=female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs plwd plwdffsint mfrm2-mfrm25 plwd_mfrm2-plwd_mfrm25
			ffsint_mfrm2-ffsint_mfrm25 plwdffsint_mfrm2-plwdffsint_mfrm25 &cov. / clb;
run;

proc export data=&tempwork..&dv.&out.nonsnp
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/models_collapsed_dddnonsnp.xlsx"
	dbms=xlsx
	replace;
	sheet="&dv.&out.nonsnp";
run;
%mend;

*avgopcountq;
%dddnonsnp(avgopcount,out=base);
%dddnonsnp(avgopcount,cov=dualmo lismo, out=ses);
%dddnonsnp(avgopcount,cov=dualmo lismo cc:, out=cc);
%dddnonsnp(avgopcount,cov=dualmo lismo cc: y_2017 y_2018, out=yr);
%dddnonsnp(avgopcount,cov=dualmo lismo cc: y_2017 y_2018 m_2-m_12, out=cyc);

*avgopcountvdq;
%dddnonsnp(avgopcountvd,out=base);
%dddnonsnp(avgopcountvd,cov=dualmo lismo, out=ses);
%dddnonsnp(avgopcountvd,cov=dualmo lismo cc:, out=cc);
%dddnonsnp(avgopcountvd,cov=dualmo lismo cc: y_2017 y_2018, out=yr);
%dddnonsnp(avgopcountvd,cov=dualmo lismo cc: y_2017 y_2018 m_2-m_12, out=cyc);

*any IP;
%dddnonsnp(fl_ip,out=base);
%dddnonsnp(fl_ip,cov=dualmo lismo, out=ses);
%dddnonsnp(fl_ip,cov=dualmo lismo cc:, out=cc);
%dddnonsnp(fl_ip,cov=dualmo lismo cc: y_2017 y_2018, out=yr);
%dddnonsnp(fl_ip,cov=dualmo lismo cc: y_2017 y_2018 m_2-m_12, out=cyc);

%let dv=avgopcount;
proc reg data=&tempwork..collapsednonsnp;
	weight benecount;
	where mosfrmplwd ne . or mosfrmarthglau ne .;
	model &dv=ffs plwd female race_db race_dh race_da race_dn race_do age3y2-age3y9;
run;
