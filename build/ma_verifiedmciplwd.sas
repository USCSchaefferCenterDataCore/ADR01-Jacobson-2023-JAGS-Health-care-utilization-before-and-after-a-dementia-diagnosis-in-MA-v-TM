/*********************************************************************************************/
title1 'Exploring AD Incidence Definition';

* Author: PF;
* Purpose: 	Verified ADRD Valid Verified Scenarios - verified in 1 year
		- 1) ADRD + RX drug
		- 2) ADRD + ADRD 
		- 3) ADRD + Dementia Symptoms
		- 4) ADRD + Death	
		Merging together AD drugs, Dementia claims, dementia symptoms, specialists,
		& relevant CPT codes to make final analytical file
		- Adding limits to the verifications:
			- Death needs to occur within a year for it to count as a verify condition
			- All other verification needs to occur within 2 years for it count as a verify countion;

* Input: dementia_dx_2001_2016, addrugs_0616;
* Output: ADinc_0213_lim;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%let minyear=2015;
%let maxyear=2018;

%let mindatayear=15;
%let maxdatayear=18;

%let demogyear=2020;

options obs=max;

***** Creating base file;
data &tempwork..analytical_ma;
	format year best4.;
	merge demdx.dementia_dt_ma&mindatayear._&maxdatayear. (in=a rename=clm_thru_dt=date keep=dxtypes bene_id clm_thru_dt demdx1-demdx26) &datalib..bene_demog&demogyear. (in=b keep=bene_id death_date);
	by bene_id;

	year=year(date);

	if bene_id ne "";

	if a and b;

	if find(dxtypes,'m') then mci=1;
	if compress(dxtypes,'X','l') ne "" then adrd=1;

run;

***** Analysis of AD Incidence;
%macro ma_mciinc_1yrv;
data &outlib..dxmciincv1yrv_scendx_ma;
	set &tempwork..analytical_ma;
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
				else if scen_dx_inc&yr.=. and year(date)=&yr. then scen_dx_dx2dt&yr.=date;
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

	drop demdx: dxtypes;
run;
%mend;

%ma_mciinc_1yrv;

options obs=max;


