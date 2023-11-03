/*********************************************************************************************/
title1 'Highly Complete Contracts';

* Author: PF;
* Purpose: 	Import the list of highly complete contracts from Jung et al and flag everyone 
	in a complete contract from 2015-2018;
* Input: ma_complete_contracts.csv, mbsf.mbsf_abcd_2015-mbsf.mbsf_abcd_2018;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

options obs=max;
data &outlib..ma_complete_contracts;
	infile "&rootpath./Projects/Programs/MAFFSpilot/ma_complete_contracts.csv" dsd dlm="2c"x missover firstobs=2;
	informat
		year best12.
		contract_id $5.
		org $50.;
	format
		year best12.
		contract_id $5.
		org $50.;
	input
		year 
		contract_id 
		org ;
run;

* Identify the beneficiaries with a complete Part C contract in all months from 2015-2018;
%macro complete;
%do yr=2015 %to 2018;
data mbsf&yr.;
	set mbsf.mbsf_abcd_&yr. (keep=bene_id bene_death_dt ptc_cntrct_id_01-ptc_cntrct_id_12);
	year=&yr.;
	array ptc [*] ptc_cntrct_id_01-ptc_cntrct_id_12;

	death_yr=year(bene_death_dt);
	death_mo=month(bene_death_dt);

	do mo=1 to min(death_mo,12);
		month=mo;
		contract_id=ptc[mo];
		output;
	end;
	keep bene_id year month contract_id;
run;

proc sql;
	create table mbsfcomplete&yr. as
	select m.*, (c.contract_id ne "") as complete
	from mbsf&yr. as m left join &outlib..ma_complete_contracts as c
	on m.contract_id=c.contract_id and m.year=c.year;
quit;

proc means data=mbsfcomplete&yr. noprint nway;
	class bene_id;
	output out=benecomplete&yr. (drop=_type_ rename=(_freq_=totalmo)) sum(complete)=completemo;
run;

data benecomplete&yr.;
	set benecomplete&yr.;
	complete&yr.=(completemo=totalmo);
	drop completemo totalmo;
run;

%end;
%mend;

%complete;
 
* Merge together complete variables from each year;
data &outlib..benecomplete1518;
	merge benecomplete2015-benecomplete2018;
	by bene_id;
run;


