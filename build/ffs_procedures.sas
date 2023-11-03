/*********************************************************************************************/
title1 'Annual Well Visit Analysis';

* Author: PF;
* Purpose: Pull Procedure Codes for Preventive Care;
* Input: [ctyp]_hcpcs&year;
* Output: Getting all claims with a procedure code unique on a bene_id, claim thru date (for 
	inpatient file using admsnt date) and provider number (for carrier files using attending 
	physician);

options compress=yes nocenter ls=150 ps=200 errors=5 errorcheck=strict mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%let awv="G0438","G0439";
%let ippe="G0344","G0402";
%let lipid="80061";
%let lipid_cholesterol="82465";
%let lipid_lipoproteins="83718";
%let lipid_triglycerides="84478";
%let mammography="77067","G0202","G0204","G0206";
%let mammography_add="77063";
%let pelvic_breast="G0101";
%let FOTB="82270";
%let sigmoidoscopy="G0104";
%let colonoscopy="G0105","G0121";
%let PSA="G0103";
%let DRE="G0102";
%let flushot_admin="G0008";
%let flushot="90658";
%let glucose_quant="82947";
%let glucose_post="82950";
%let GTT="82951";

%let minyear=2015;
%let maxyear=2018;

%let max_prcdr=15;

options obs=max;

%macro get(ctyp,byear,eyear,dropv=,keepv=,byv=);
	%do year=&byear %to &eyear;
		data &tempwork..preventive_&ctyp._&year._;
		
			set 
				
			%if &year<&demogvq %then %do;
				%do mo=1 %to 12;
					%if &mo<10 %then %do;
						rif&year..&ctyp._claims_0&mo (keep=bene_id clm_thru_dt icd_prcdr_cd: prcdr_dt: &keepv drop=&dropv)
					%end;
					%else %if &mo>=10 %then %do;
						rif&year..&ctyp._claims_&mo (keep=bene_id clm_thru_dt icd_prcdr_cd: prcdr_dt: &keepv drop=&dropv)
					%end;
				%end;
			%end;
			%else %if &year>=&demogvq %then %do;
				%do mo=1 %to 12;
					%if &mo<10 %then %do;
						rifq&year..&ctyp._claims_0&mo (keep=bene_id clm_thru_dt icd_prcdr_cd: prcdr_dt: &keepv drop=&dropv)
					%end;
					%else %if &mo>=10 %then %do;
						rifq&year..&ctyp._claims_&mo (keep=bene_id clm_thru_dt icd_prcdr_cd: prcdr_dt: &keepv drop=&dropv)
					%end;
				%end;
			%end;
			;
			by bene_id &byv;
		
		year=year(clm_thru_dt);
		
		length prev_prcdr_cd1-prev_prcdr_cd&max_prcdr $7;

		array prevprcdr [*] prev_prcdr_cd1-prev_prcdr_cd&max_prcdr;
		array prcdr [*] icd_prcdr_cd:;

			do i=1 to dim(prevprcdr);
				prevprcdr[i]="";
			end;
			prcdrsub=0;
			awv=0;
			ippe=0;
			lipid=0;
			lipid_cholesterol=0;
			lipid_lipoproteins=0;
			lipid_triglycerides=0;
			mammography=0;
			mammography_add=0;
			pelvic_breast=0;
			FOTB=0;
			sigmoidoscopy=0;
			colonoscopy=0;
			PSA=0;
			DRE=0;
			flushot_admin=0;
			flushot=0;
			glucose_quant=0;
			glucose_post=0;
			GTT=0;
			anypreventive=0;

		do i=1 to dim(prcdr);
			if prcdr[i] in(&awv) then awv=1;
			if prcdr[i] in(&ippe) then ippe=1;
			if prcdr[i] in(&lipid) then lipid=1;
			if prcdr[i] in(&lipid_cholesterol) then lipid_cholesterol=1;
			if prcdr[i] in(&lipid_lipoproteins) then lipid_lipoproteins=1;
			if prcdr[i] in(&lipid_triglycerides) then lipid_triglycerides=1;
			if prcdr[i] in(&mammography) then mammography=1;
			if prcdr[i] in(&mammography_add) then mammography_add=1;
			if prcdr[i] in(&pelvic_breast) then pelvic_breast=1;
			if prcdr[i] in(&FOTB) then FOTB=1;
			if prcdr[i] in(&sigmoidoscopy) then sigmoidoscopy=1;
			if prcdr[i] in(&colonoscopy) then colonoscopy=1;
			if prcdr[i] in(&PSA) then PSA=1;
			if prcdr[i] in(&DRE) then DRE=1;
			if prcdr[i] in(&flushot_admin) then flushot_admin=1;
			if prcdr[i] in(&flushot) then flushot=1;
			if prcdr[i] in(&glucose_quant) then glucose_quant=1;
			if prcdr[i] in(&glucose_post) then glucose_post=1;
			if prcdr[i] in(&GTT) then GTT=1;
			if prcdr[i] in(&awv,&ippe,&lipid,&lipid_cholesterol,&lipid_lipoproteins,&lipid_triglycerides,&mammography,&mammography_add,&pelvic_breast,&FOTB,&sigmoidoscopy,
			&colonoscopy,&PSA,&DRE,&flushot_admin,&flushot,&glucose_quant,&glucose_post,&GTT) then do;
				anypreventive=1;
				found=0;
				do j=1 to prcdrsub;
					if prcdr[i]=prevprcdr[j] then found=j;
				end;
				if found=0 then do;
					prcdrsub=prcdrsub+1;
					if prcdrsub<=&max_prcdr then prevprcdr[prcdrsub]=prcdr[i];
				end;
			end;
		end;
		month=month(clm_thru_dt);
		if anypreventive;
       
    length clm_typ $1;
    
    if "%substr(&ctyp,1,1)" = "i" then clm_typ="1"; /* inpatient */
    else if "%substr(&ctyp,1,1)" = "s" then clm_typ="2"; /* SNF */
    else if "%substr(&ctyp,1,1)" = "o" then clm_typ="3"; /* outpatient */
    else if "%substr(&ctyp,1,1)" = "h" then clm_typ="4"; /* home health */
    else if "%substr(&ctyp,1,1)" = "b" then clm_typ="5"; /* carrier */
    else clm_typ="X";  
    
	drop icd_prcdr_cd: prcdr_dt1-prcdr_dt25 i j found prcdrsub;
run;	

proc means data=&tempwork..preventive_&ctyp._&year._ noprint nway missing;
	class bene_id clm_thru_dt &keepv. clm_typ;
	var awv--anypreventive;
	output out=&tempwork..preventive_&ctyp._&year. (drop=_type_ _freq_) max()=;
run;
%end;
%mend get;

/*
%get(bcarrier,&minyear,&maxyear,dropv=,keepv=carr_clm_blg_npi_num,byv=bene_id);*/

%get(inpatient,&minyear,&maxyear,dropv=,
			 keepv=org_npi_num,byv=);	

%get(outpatient,&minyear,&maxyear,dropv=,
			 keepv=org_npi_num,byv=);	

* Revenue files;
%macro revenue(ctyp,proctyp,byear,eyear,procdt=,keepv=);
%do year=&byear %to &eyear;
	%do mo=1 %to 12;
data &tempwork..preventive_r&ctyp._&year._&mo._;
		set 
			%if &year<&demogvq %then %do;
					%if &mo<10 %then %do;
						rif&year..&ctyp._&proctyp._0&mo (keep=bene_id clm_thru_dt &procdt hcpcs_cd clm_id)
					%end;
					%if &mo>=10 %then %do;
						rif&year..&ctyp._&proctyp._&mo (keep=bene_id clm_thru_dt &procdt hcpcs_cd clm_id) 
					%end;
			%end;
			%else %if &year>=&demogvq %then %do;
					%if &mo<10 %then %do;
						rifq&year..&ctyp._&proctyp._0&mo (keep=bene_id clm_thru_dt &procdt hcpcs_cd clm_id)
					%end;
					%if &mo>=10 %then %do;
						rifq&year..&ctyp._&proctyp._&mo (keep=bene_id clm_thru_dt &procdt hcpcs_cd clm_id) 
					%end;
			%end;
				;
		by bene_id clm_id;

		year=year(clm_thru_dt);
	
		length prev_prcdr_cd1-prev_prcdr_cd&max_prcdr $7;
		array prevprcdr [*] prev_prcdr_cd1-prev_prcdr_cd&max_prcdr;

			do i=1 to dim(prevprcdr);
				prevprcdr[i]="";
			end;
			prcdrsub=0;
			awv=0;
			ippe=0;
			lipid=0;
			lipid_cholesterol=0;
			lipid_lipoproteins=0;
			lipid_triglycerides=0;
			mammography=0;
			mammography_add=0;
			pelvic_breast=0;
			FOTB=0;
			sigmoidoscopy=0;
			colonoscopy=0;
			PSA=0;
			DRE=0;
			flushot_admin=0;
			flushot=0;
			glucose_quant=0;
			glucose_post=0;
			GTT=0;
			anypreventive=0;

		if hcpcs_cd in(&awv) then awv=1;
		if hcpcs_cd in(&ippe) then ippe=1;
		if hcpcs_cd in(&lipid) then lipid=1;
		if hcpcs_cd in(&lipid_cholesterol) then lipid_cholesterol=1;
		if hcpcs_cd in(&lipid_lipoproteins) then lipid_lipoproteins=1;
		if hcpcs_cd in(&lipid_triglycerides) then lipid_triglycerides=1;
		if hcpcs_cd in(&mammography) then mammography=1;
		if hcpcs_cd in(&mammography_add) then mammography_add=1;
		if hcpcs_cd in(&pelvic_breast) then pelvic_breast=1;
		if hcpcs_cd in(&FOTB) then FOTB=1;
		if hcpcs_cd in(&sigmoidoscopy) then sigmoidoscopy=1;
		if hcpcs_cd in(&colonoscopy) then colonoscopy=1;
		if hcpcs_cd in(&PSA) then PSA=1;
		if hcpcs_cd in(&DRE) then DRE=1;
		if hcpcs_cd in(&flushot_admin) then flushot_admin=1;
		if hcpcs_cd in(&flushot) then flushot=1;
		if hcpcs_cd in(&glucose_quant) then glucose_quant=1;
		if hcpcs_cd in(&glucose_post) then glucose_post=1;
		if hcpcs_cd in(&GTT) then GTT=1;

		if hcpcs_cd in(&awv,&ippe,&lipid,&lipid_cholesterol,&lipid_lipoproteins,&lipid_triglycerides,&mammography,&mammography_add,&pelvic_breast,&FOTB,&sigmoidoscopy,
		&colonoscopy,&PSA,&DRE,&flushot_admin,&flushot,&glucose_quant,&glucose_post,&GTT) then do;
			anypreventive=1;
			found=0;
			do j=1 to prcdrsub;
				if hcpcs_cd=prevprcdr[j] then found=j;
			end;
			if found=0 then do;
				prcdrsub=prcdrsub+1;
				if prcdrsub<=&max_prcdr then prevprcdr[prcdrsub]=hcpcs_cd;
			end;
		end;

		month=month(clm_thru_dt);
		if anypreventive;

		length clm_typ $1;
    
	    if "%substr(&ctyp,1,1)" = "i" then clm_typ="1"; /* inpatient */
	    else if "%substr(&ctyp,1,1)" = "s" then clm_typ="2"; /* SNF */
	    else if "%substr(&ctyp,1,1)" = "o" then clm_typ="3"; /* outpatient */
	    else if "%substr(&ctyp,1,1)" = "h" then clm_typ="4"; /* home health */
	    else if "%substr(&ctyp,1,1)" = "b" then clm_typ="5"; /* carrier */
	    else clm_typ="X";  

		drop hcpcs_cd found prcdrsub i j;

run;

* Merging to get org_npi for these claims;
data &tempwork..preventive_r&ctyp._&year._&mo._1;
	merge &tempwork..preventive_r&ctyp._&year._&mo._ (in=a) 
	%if &mo.<10 %then rif&year..&ctyp._claims_0&mo. (in=b keep=bene_id clm_id &keepv);
	%if &mo.>=10 %then rif&year..&ctyp._claims_&mo. (in=b keep=bene_id clm_id &keepv);
	;
	by bene_id clm_id;
	if a;
run;

proc means data=&tempwork..preventive_r&ctyp._&year._&mo._1 noprint nway missing;
	class bene_id clm_thru_dt &keepv. clm_typ;
	var awv--anypreventive;
	output out=&tempwork..preventive_r&ctyp._&year._&mo. (drop=_type_ _freq_) max()=;
run;
	%end;

data &tempwork..preventive_r&ctyp._&year.;
	set &tempwork..preventive_r&ctyp._&year._1-&tempwork..preventive_r&ctyp._&year._12;
	by bene_id clm_thru_dt &keepv. clm_typ;
run;

%end;
%mend;

%let maxyear=2018;

%macro append(ctyp,revenueonly=Y,keepv=);
	
data &tempwork..preventive_&ctyp._&minyear._&maxyear;
		set 
	%if "&revenueonly"="Y" %then %do year=&minyear %to &maxyear;
		&tempwork..preventive_r&ctyp._&year
	%end;
	%else %do year=&minyear %to &maxyear;
		&tempwork..preventive_&ctyp._&year
		&tempwork..preventive_r&ctyp._&year
	%end; ;
	by bene_id clm_thru_dt &keepv. clm_typ;
	if bene_id=. then delete;
	if not(first.clm_typ and last.clm_typ) then check=1;
	%if "&ctyp."="bcarrier" %then rename &keepv=org_npi_num;;
run;

%mend;

%revenue(inpatient,revenue,&minyear,&maxyear,keepv=org_npi_num);
%append(inpatient,revenueonly=N,keepv=org_npi_num)

%revenue(outpatient,revenue,&minyear,&maxyear,keepv=org_npi_num);
%append(outpatient,revenueonly=N,keepv=org_npi_num)

%revenue(bcarrier,line,&minyear,&maxyear,keepv=carr_clm_blg_npi_num);
%append(bcarrier,revenueonly=Y,keepv=carr_clm_blg_npi_num);

%revenue(hha,revenue,&minyear,&maxyear,keepv=org_npi_num);
%append(hha,revenueonly=Y,keepv=org_npi_num);

%revenue(snf,revenue,&minyear,&maxyear,keepv=org_npi_num);
%append(snf,revenueonly=Y,keepv=org_npi_num);

data &tempwork..preventiveprcdr_&minyear._&maxyear.;
	set &tempwork..preventive_bcarrier_&minyear._&maxyear. &tempwork..preventive_hha_&minyear._&maxyear. &tempwork..preventive_inpatient_&minyear._&maxyear.
	&tempwork..preventive_outpatient_&minyear._&maxyear. &tempwork..preventive_snf_&minyear._&maxyear.;
	by bene_id clm_thru_dt org_npi_num clm_typ;
	month=month(clm_thru_dt);
	year=year(clm_thru_dt);
run;

* Getting a monthly count;
proc means data=&tempwork..preventiveprcdr_&minyear._&maxyear. noprint nway;
	class year month;
	var awv--anypreventive;
	output out=&outlib..ffs_preventiveprcdr1518 (drop=_type_ _freq_) sum()=;
run;

proc means data=&tempwork..preventiveprcdr_&minyear._&maxyear. noprint nway;
	class bene_id year month;
	var awv--anypreventive;
	output out=&outlib..ffs_bene_preventiveprcdr1518 (drop=_type_ _freq_) sum()=;
run;

options obs=max;




