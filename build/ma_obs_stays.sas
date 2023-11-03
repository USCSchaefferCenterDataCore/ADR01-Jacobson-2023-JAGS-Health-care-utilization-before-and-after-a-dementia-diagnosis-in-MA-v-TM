/*********************************************************************************************/
title1 'MA/ma Pilot';

* Author: PF;
* Purpose: Pull Unique Observation Stays;
* Input: op revenue claims and base files and ip base 2015-2018;
* Output: monthly obs stay count;

options compress=yes nocenter ls=150 ps=200 errors=5 errorcheck=strict mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%let cpt="99217" "99218" "99218" "99220" "99224" "99225" "99226" "99234" "99235" "99236";
%let rev="0762" "0760";

%macro ma_obs;
%do yr=15 %to 18;
		* pull all obs stay claims from revenue center;
		data obs_ma&yr._;
			set  enrfpl&yr..op_revenue_enc (keep=bene_id enc_join_key clm_thru_dt rev_cntr hcpcs_cd)
				;
			if rev_cntr in(&rev.) or hcpcs_cd in(&cpt.);
		run;

		proc sql;
			* merge on org_npi;
			create table obs_ma&yr._a as 
			select x.*, y.clm_from_dt, y.org_npi
			from obs_ma&yr._ as x left join enrfpl&yr..op_base_enc as y
			on x.bene_id=y.bene_id and x.enc_join_key=y.enc_join_key;

			* merge on ip stays;
			create table obs_ma&yr._b as 
			select x.*, y.clm_admsn_dt, y.bene_dschrg_dt,y.clm_from_dt as ip_clm_from_dt, y.clm_thru_dt as ip_clm_thru_dt
			from obs_ma&yr._a as x left join enrfpl&yr..ip_base_enc as y
			on x.bene_id=y.bene_id and x.clm_from_dt<=y.bene_dschrg_dt;

		quit;

		* delete observation stays that lead to ip admission
			- dropping any overlap with admsn date and dischrg date and admissions that occur on clm_thru_dt or after;
		data obs_ma&yr. obs_ma_drops&yr.;
			set obs_ma&yr._b;

			* fill in  any missing admission or discharge dates with clm_from_dt, clm_thru_dt;
			if clm_admsn_dt=. then clm_admsn_dt=ip_clm_from_dt;
			if bene_dschrg_dt=. then bene_dschrg_dt=ip_clm_thru_dt;

			* flag admissions that occur on same day as an obs stay discharge;
			if clm_thru_dt=clm_admsn_dt then drop=1;
			*flag admissions that occur on the day after an obs stay;
			else if clm_thru_dt+1=clm_admsn_dt then drop=2;
			* flag admissions that overlap with an obs stay;
			else if clm_admsn_dt<=clm_thru_dt<=bene_dschrg_dt then drop=3;

			if drop ne . then output obs_ma_drops&yr.;
			else output obs_ma&yr.;
		run;

		proc freq data=obs_ma_drops&yr.;
			table drop / out=freq_madrops&yr.;
		run;

		* remove drops from the original;
		proc sort data=obs_ma_drops&yr. nodupkey; by bene_id enc_join_key; run;
		proc sort data=obs_ma&yr.; by bene_id enc_join_key; run;

		data obs_manonip&yr.;
			merge obs_ma&yr. (in=a) obs_ma_drops&yr. (in=b keep=bene_id enc_join_key);
			by bene_id enc_join_key;
			if a and not b;

			* flagging obs in two ways 1) resdac 2) lind et al - includes all the ICD codes;
			obs1=0;
			* resdac;
			if rev_cntr="0762" then obs1=1;
			* lind et al;
			obs2=1;

			mo=month(clm_thru_dt);
			year=year(clm_thru_dt);
		run;

		* remove duplicates - bene_id, clm_thru_dt, org_npi;
		proc sort data=obs_manonip&yr. nodupkey out=obs1_manonip&yr.;
			where obs1=1;
			by bene_id clm_thru_dt org_npi;
		run;

		proc sort data=obs_manonip&yr. nodupkey out=obs2_manonip&yr.;
			where obs2=1;
			by bene_id clm_thru_dt org_npi;
		run;

		* monthly counts;
		proc means data=obs1_manonip&yr. noprint nway;
			class bene_id year mo;
			var obs1;
			output out=obs1_manonip&yr._mo (drop=_type_ _freq_) sum(obs1)=;
		run;

		proc means data=obs2_manonip&yr. noprint nway;
			class bene_id year mo;
			var obs2;
			output out=obs2_manonip&yr._mo (drop=_type_ _freq_) sum(obs2)=;
		run;

		data obsmo_manonip&yr.;
			merge obs1_manonip&yr._mo obs2_manonip&yr._mo;
			by bene_id year mo;
		run;		

%end;
%mend;

%ma_obs;

* Stack all;
data &tempwork..ma_obs1518;
	set obsmo_manonip15-obsmo_manonip18;
run;







