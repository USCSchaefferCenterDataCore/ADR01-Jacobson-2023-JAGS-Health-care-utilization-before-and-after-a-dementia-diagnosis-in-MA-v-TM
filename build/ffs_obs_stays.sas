/*********************************************************************************************/
title1 'MA/FFS Pilot';

* Author: PF;
* Purpose: Pull Unique Observation Stays;
* Input: outpatient revenue claims and base files and inpatient base 2015-2018;
* Output: monthly obs stay count;

options compress=yes nocenter ls=150 ps=200 errors=5 errorcheck=strict mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%let cpt="99217" "99218" "99218" "99220" "99224" "99225" "99226" "99234" "99235" "99236";
%let rev="0762" "0760";

options obs=max;
%macro ffs_obs;
%do yr=2015 %to 2018;
	%do mo=1 %to 12;
		* pull all obs stay claims from revenue center;
		data obs_ffs&yr._&mo.;
			set %if &mo<10 %then rif&yr..outpatient_revenue_0&mo. (keep=bene_id clm_id clm_thru_dt rev_cntr hcpcs_cd);
				%if &mo>=10 %then rif&yr..outpatient_revenue_&mo. (keep=bene_id clm_id clm_thru_dt rev_cntr hcpcs_cd);
				;
			if rev_cntr in(&rev.) or hcpcs_cd in(&cpt.);
		run;

		proc sql;
			* merge on org_npi;
			create table obs_ffs&yr._a&mo. as 
			select x.*, y.clm_from_dt, y.org_npi_num
			from obs_ffs&yr._&mo. as x left join 
			%if &mo<10 %then rif&yr..outpatient_claims_0&mo. as y;
			%if &mo>=10 %then rif&yr..outpatient_claims_&mo. as y;
			on x.bene_id=y.bene_id and x.clm_id=y.clm_id;

			* merge on inpatient stays;
			create table obs_ffs&yr._b&mo. as 
			select x.*, y.clm_admsn_dt, y.nch_bene_dschrg_dt,y.clm_from_dt as ip_clm_from_dt, y.clm_thru_dt as ip_clm_thru_dt
			from obs_ffs&yr._a&mo. as x left join 
			%if &mo<10 %then rif&yr..inpatient_claims_0&mo. as y;
			%if &mo>=10 %then rif&yr..inpatient_claims_&mo. as y;
			on x.bene_id=y.bene_id and x.clm_from_dt<=y.nch_bene_dschrg_dt;

		quit;
	%end;

		* delete observation stays that lead to inpatient admission
			- dropping any overlap with admsn date and dischrg date and admissions that occur on clm_thru_dt or after;
		data obs_ffs&yr. obs_ffs_drops&yr.;
			set obs_ffs&yr._b1-obs_ffs&yr._b12;

			* fill in  any missing admission or discharge dates with clm_from_dt, clm_thru_dt;
			if clm_admsn_dt=. then clm_admsn_dt=ip_clm_from_dt;
			if nch_bene_dschrg_dt=. then nch_bene_dschrg_dt=ip_clm_thru_dt;

			* flag admissions that occur on same day as an obs stay discharge;
			if clm_thru_dt=clm_admsn_dt then drop=1;
			*flag admissions that occur on the day after an obs stay;
			else if clm_thru_dt+1=clm_admsn_dt then drop=2;
			* flag admissions that overlap with an obs stay;
			else if clm_admsn_dt<=clm_thru_dt<=nch_bene_dschrg_dt then drop=3;

			if drop ne . then output obs_ffs_drops&yr.;
			else output obs_ffs&yr.;
		run;

		proc freq data=obs_ffs_drops&yr.;
			table drop / out=freq_ffsdrops&yr.;
		run;

		* remove drops from the original;
		proc sort data=obs_ffs_drops&yr. nodupkey; by bene_id clm_id; run;
		proc sort data=obs_ffs&yr.; by bene_id clm_id; run;

		data obs_ffsnonip&yr.;
			merge obs_ffs&yr. (in=a) obs_ffs_drops&yr. (in=b keep=bene_id clm_id);
			by bene_id clm_id;
			if a and not b;

			* flagging obs in two ways 1) resdac 2) lind et al - includes all the ICD codes;
			obs1=0;
			* resdac;
			if rev_cntr="0762" then obs1=1;
			* lind et al;
			obs2=1;

			mo=month(clm_thru_dt);
			year=&yr.;
		run;

		* remove duplicates - bene_id, clm_thru_dt, org_npi;
		proc sort data=obs_ffsnonip&yr. nodupkey out=obs1_ffsnonip&yr.;
			where obs1=1;
			by bene_id clm_thru_dt org_npi_num;
		run;

		proc sort data=obs_ffsnonip&yr. nodupkey out=obs2_ffsnonip&yr.;
			where obs2=1;
			by bene_id clm_thru_dt org_npi_num;
		run;

		* monthly counts;
		proc means data=obs1_ffsnonip&yr. noprint nway;
			class bene_id year mo;
			var obs1;
			output out=obs1_ffsnonip&yr._mo (drop=_type_ _freq_) sum(obs1)=;
		run;

		proc means data=obs2_ffsnonip&yr. noprint nway;
			class bene_id year mo;
			var obs2;
			output out=obs2_ffsnonip&yr._mo (drop=_type_ _freq_) sum(obs2)=;
		run;

		data obsmo_ffsnonip&yr.;
			merge obs1_ffsnonip&yr._mo obs2_ffsnonip&yr._mo;
			by bene_id year mo;
		run;		

%end;
%mend;

%ffs_obs;

* Stack all;
data &tempwork..ffs_obs1518;
	set obsmo_ffsnonip2015-obsmo_ffsnonip2018;
run;







