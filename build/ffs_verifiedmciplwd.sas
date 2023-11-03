/*********************************************************************************************/
title1 'Exploring AD Incidence Definition';

* Author: PF;
* Purpose: 	Verified MCI in 1 year
	- verified by second MCI or death
	- first dx in that year has to be an MCI - if there is an dementia dx prior to the MCI, then
	  drop
	- take these beneficiaries in each year and find a second either MCI or dementia dx for them
	  using the prior methods
	- compare against verified dementia, if there is a verified dementia date that occurs before 
	  verified MCI, then not verified MCI - crosstab those who later progress from MCI to dementia;
* Input: dementia_dx_2001_2016, addrugs_0616;
* Output: ADinc_0213_lim;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%let minyear=2015;
%let maxyear=2018;

%let mindatayear=1999;
%let maxdatayear=2020;

%let demogyear=2020;

options obs=max;

***** Creating base file;

data &tempwork..analytical_ffs;
	format year best4.;
	merge demdx.dementia_dt_&mindatayear._&maxdatayear. (in=a rename=demdx_dt=date keep=dxtypes bene_id year demdx_dt demdx1-demdx26) &datalib..bene_demog&demogyear. (in=b keep=bene_id death_date);
	by bene_id;

	if bene_id ne "";

	if a and b;

	if find(dxtypes,'m') then mci=1;
	if compress(dxtypes,'X','l') ne "" then adrd=1;

run;

* Limit to people whose first dx in that year is an MCI - dementia dx comes after;
options obs=max;
/*
data &tempwork..validmci;
	set ad.bene_adrdclaims_yearly9919 (keep=bene_id firstdx_yr2015-firstdx_yr2018 firstmci_yr2015-firstmci_yr2018);
	by bene_id;
	array dx [2015:2018] firstdx_yr2015-firstdx_yr2018;
	array mci [2015:2018] firstmci_yr2015-firstmci_yr2018;
	format firstmci firstdx mmddyy10.;
	do i=2015 to 2018;
		if .<mci[i]<dx[i] or (dx[i]=. and mci[i] ne .) then do;
			firstmci=mci[i];
			firstdx=dx[i];
			year=i;
			validmci=1;
			output;
		end;
	end;
run;

proc sort data=&tempwork..validmci;
	by bene_id year firstmci;
run;

data &tempwork..analytical_ffs_mci;
	merge &tempwork..analytical_ffs (in=a) &tempwork..validmci (in=b keep=bene_id year firstmci validmci rename=(firstmci=date));
	by bene_id year date;
	if compress(dxtypes,'X','l') ne "" then adrd=1;
run;
*/
***** Analysis of AD Incidence;
%macro ffs_dxmciinc_1yrv;
data &outlib..dxmciincv1yrv_scendx_ffs;
	set &tempwork..analytical_ffs;
	by bene_id year date;

	* Scenario 1: Two records of AD Diagnosis;
	
	%do yr=&minyear. %to &maxyear;
		retain scen_dx_inc&yr. scen_dx_vtime&yr. scen_dx_dx2dt&yr. scen_dx_inctype&yr. scen_dx_vtype&yr. scen_dx_vdt&yr. ;
		format scen_dx_inc&yr. scen_dx_vdt&yr. scen_dx_dx2dt&yr. mmddyy10. scen_dx_inctype&yr. scen_dx_vtype&yr. $4.;
		if (first.year and year=&yr.) or first.bene_id then do;
			scen_dx_inc&yr.=.;
			scen_dx_inctype&yr.="";
			scen_dx_vtype&yr.="";
			scen_dx_vtime&yr.=.;
			scen_dx_dx2dt&yr.=.;
			scen_dx_vdt&yr.=.;
		end;
		if year>=&yr. then do;
			if mci=1 or adrd=1 then do;
				if scen_dx_inc&yr.=. and .<date-scen_dx_dx2dt&yr.<=365 then do;
					scen_dx_inc&yr.=scen_dx_dx2dt&yr.;
					scen_dx_vdt&yr.=date;
					scen_dx_vtime&yr.=date-scen_dx_inc&yr.;
					scen_dx_inctype&yr.="1";
					scen_dx_vtype&yr.="1";
				end;
				else if scen_dx_inc&yr.=. and year(date)=&yr. then scen_dx_dx2dt&yr.=date; * this can only be the valid MCI date in that year;
			end;
		end;
	%end;

	* Death scenarios;
	%do yr=&minyear. %to &maxyear.;
	if (first.year and year=&yr.) or first.bene_id then do;
		death_dx&yr.=.;
		death_dx_type&yr.="    ";
		death_dx_vtime&yr.=.;
	end;
	retain death_dx:;
	format death_dx&yr. death_date mmddyy10.;
	if year=&yr. then do;
		if death_dx&yr.=. and (mci or adrd) and .<death_date-date<=365 then do;
			death_dx&yr.=date;
			death_dx_vtime&yr.=death_date-date;
			death_dx_type&yr.="1";
		end;
	end;
	%end;
	
	* Using death scenario as last resort if missing;
	if last.bene_id then do;
		%do yr=&minyear. %to &maxyear.;
		if scen_dx_inc&yr.=. and death_dx&yr. ne . then do;
			scen_dx_inc&yr.=death_dx&yr.;
			scen_dx_vdt&yr.=death_date;
			scen_dx_vtime&yr.=death_dx_vtime&yr.;
			scen_dx_inctype&yr.=death_dx_type&yr.;
			scen_dx_vtype&yr.="   4";
		end;
		%end;
	end;
	
	%do yr=&minyear. %to &maxyear.;
	if .<scen_dx_vtime&yr.<0 then dropdx&yr.=1;
	
	label 
	scen_dx_inc&yr.="ADRD incident date for scenario using only dx"
	scen_dx_vdt&yr.="Date of verification for scenario using only dx"
	scen_dx_vtime&yr.="Verification time for scenario using only dx"
	scen_dx_inctype&yr.="1-incident date is ADRD dx, 2-incident date is drug use, 3-incident date is dem symptom"
	scen_dx_vtype&yr.="1-verification date is ADRD dx, 2-verification date is drug use, 3-verification date is dem symptom, 4-verified by death"
	;
	%end;

	if last.bene_id;

	drom demdx: dxtypes;
run;

%mend;

%ffs_dxmciinc_1yrv;

options obs=max;


