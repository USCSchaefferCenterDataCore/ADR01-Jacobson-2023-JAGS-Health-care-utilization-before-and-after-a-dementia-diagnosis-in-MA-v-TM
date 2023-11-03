/*********************************************************************************************/
title1 'MA/FFS - Exclude SNP';

* Author: PF;
* Purpose: Identify SNP plans from 2015-2018 - any SNP in month;
* Input: Part D Characteristics File;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

options obs=max;
* Identify the beneficiaries with a complete Part C contract in all months from 2015-2018;
%macro snp;
%do yr=2015 %to 2018;
data mbsf&yr.;
	set mbsf.mbsf_abcd_&yr. (keep=bene_id bene_death_dt ptd_cntrct_id_01-ptd_cntrct_id_12 ptd_pbp_id_01-ptd_pbp_id_12);
	year=&yr.;
	array ptd [*] ptd_cntrct_id_01-ptd_cntrct_id_12;
	array pln [*] ptd_pbp_id_01-ptd_pbp_id_12;

	death_yr=year(bene_death_dt);
	death_mo=month(bene_death_dt);

	do mo=1 to min(death_mo,12);
		month=mo;
		contract_id=ptd[mo];
		plan_id=pln[mo];
		output;
	end;
	keep bene_id year month contract_id plan_id;
run;

proc sql;
	create table mbsfsnp&yr. as
	select m.*, p.snp_type, (p.plan_id ne "") as inptd
	from mbsf&yr. as m left join pdch&yr..plan_char_&yr._extract as p
	on m.contract_id=p.contract_id and m.plan_id=p.plan_id;
quit;

* Checks;
proc freq data=mbsfsnp&yr.;
	table inptd;
run;

data mbsfsnp&yr._1;
	set mbsfsnp&yr.;
	if snp_type not in("","0") then snp=1;
run;

proc means data=mbsfsnp&yr._1 noprint nway;
	class bene_id;
	output out=benesnp&yr. (drop=_type_ rename=(_freq_=totalmo)) sum(snp)=snpmo;
run;

data benesnp&yr.;
	set benesnp&yr.;
	allsnp&yr.=(snpmo=totalmo);
	anysnp&yr.=(snpmo>0);
	drop snpmo totalmo;
run;

%end;
%mend;

%snp;

* Merge together complete variables from each year;
data &outlib..benesnp1518;
	merge benesnp2015-benesnp2018;
	by bene_id;
run;
