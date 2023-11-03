/*********************************************************************************************/
title1 'LTC';

* Author: PF;
* Purpose: Stack all LTC codes together and merge with SNF file separate between SNF and LTC stays;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

options obs=max;
%let minyear=15;
%let maxyear=18;

%macro snf(byear,eyear);
%do year=&byear %to &eyear.;

%if &year<19 %then %do;
data &tempwork..ltc_all&year.;
	set  &tempwork..ltc_prcdr_&year. (rename=prcdr_dt=date keep=bene_id prcdr_dt ltc_prcdr1) &tempwork..pdeltc20&year. (rename=srvc_dt=date
		 where=(pde_ltc=1)) &tempwork..ltc_pos_carline_&year. (rename=clm_thru_dt=date);
run;
%end;
%if &year>=19 %then %do;
data &tempwork..ltc_all&year.;
	set  &tempwork..ltc_prcdr_&year. (rename=prcdr_dt=date keep=bene_id prcdr_dt ltc_prcdr1) 
	&tempwork..ltc_pos_carline_&year. (rename=clm_thru_dt=date);
run;
%end;

proc sql;
	create table &tempwork..ltc_snf&year. as
	select x.*, y.clm_admsn_dt, y.clm_from_dt, y.clm_thru_dt, (y.clm_admsn_dt ne .) as insnf
	from &tempwork..ltc_all&year. as x left join enrfpl&year..snf_base_enc as y
	on x.bene_id=y.bene_id and y.clm_admsn_dt<=x.date<=y.clm_thru_dt
	order by x.bene_id, x.date;
quit;
%end;
%mend;

%snf(&minyear.,&maxyear.);

/* LTC Bene */
%macro ltcbene;
%do yr=&minyear %to &maxyear;
data &tempwork..ltc&yr.;
	set &tempwork..ltc_snf&yr.;
	if insnf=0;
	ptd=0;
	pos=0;
	prcdr=0;
	if pde_id ne . then ptd=1;
	if line_place_of_srvc_cd ne . then pos=1;
	if ltc_prcdr1 ne . then prcdr=1;
run;

proc means data=&tempwork..ltc&yr. noprint nway;
	class bene_id;
	output out=base.ma_ltc20&yr._bene (drop=_type_ _freq_) max(ptd pos prcdr)=ptd&yr. pos&yr. prcdr&yr.;
run;
%end;
%mend;

%ltcbene;
