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

%let minyear=15;
%let maxyear=18;

%let max_prcdr=15;

options obs=max;

%macro getma(ctyp,byear,eyear,dropv=,keepv=,byv=);
	%do year=&byear %to &eyear;
		data &tempwork..mapreventive_&ctyp._&year._;
		
			set 
				enrfpl&year..&ctyp._base_enc (keep=bene_id clm_thru_dt icd_prcdr_cd: &keepv drop=&dropv)
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
    else if "%substr(&ctyp,1,1)" = "c" then clm_typ="5"; /* carrier */
    else clm_typ="X";  
    
	drop icd_prcdr_cd: i j found prcdrsub;
run;	

proc means data=&tempwork..mapreventive_&ctyp._&year._ noprint nway missing;
	class bene_id clm_thru_dt &keepv. clm_typ;
	var awv--anypreventive;
	output out=&tempwork..mapreventive_&ctyp._&year. (drop=_type_ _freq_) max()=;
run;
%end;
%mend getma;

/*
%getma(bcarrier,&minyear,&maxyear,dropv=,keepv=carr_clm_blg_npi_num,byv=bene_id);*/

%getma(ip,&minyear,&maxyear,dropv=,
			 keepv=org_npi,byv=);	

%getma(op,&minyear,&maxyear,dropv=,
			 keepv=org_npi,byv=);	

* Revenue files;
%macro revenue(ctyp,proctyp,byear,eyear,procdt=,keepv=);
%do year=&byear %to &eyear;
data &tempwork..mapreventive_r&ctyp._&year._;
		set 
			enrfpl&year..&ctyp._&proctyp._enc (keep=bene_id clm_thru_dt &procdt hcpcs_cd enc_join_key)
				;
		by bene_id enc_join_key;

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
	    else if "%substr(&ctyp,1,1)" = "c" then clm_typ="5"; /* carrier */
	    else clm_typ="X";  

		drop hcpcs_cd found prcdrsub i j;

run;

* Merging to get org_npi for these claims;
data &tempwork..mapreventive_r&ctyp._&year._1;
	merge &tempwork..mapreventive_r&ctyp._&year._ (in=a) 
		  enrfpl&year..&ctyp._base_enc (in=b keep=bene_id enc_join_key &keepv);
	by bene_id enc_join_key;
	if a;
run;

proc means data=&tempwork..mapreventive_r&ctyp._&year._1 noprint nway missing;
	class bene_id clm_thru_dt &keepv. clm_typ;
	var awv--anypreventive;
	output out=&tempwork..mapreventive_r&ctyp._&year. (drop=_type_ _freq_) max()=;
run;
%end;
%mend;

%macro append(ctyp,revenueonly=Y,keepv=);
	
data &tempwork..mapreventive_&ctyp._&minyear._&maxyear;
		set 
	%if "&revenueonly"="Y" %then %do year=&minyear %to &maxyear;
		&tempwork..mapreventive_r&ctyp._&year
	%end;
	%else %do year=&minyear %to &maxyear;
		&tempwork..mapreventive_&ctyp._&year
		&tempwork..mapreventive_r&ctyp._&year
	%end; ;
	by bene_id clm_thru_dt &keepv. clm_typ;
	if bene_id=. then delete;
	if not(first.clm_typ and last.clm_typ) then check=1;
	%if "&ctyp."="bcarrier" %then rename &keepv=org_npi_num;;
run;

%mend;

%revenue(ip,revenue,&minyear,&maxyear,keepv=org_npi);
%append(ip,revenueonly=N,keepv=org_npi)

%revenue(op,revenue,&minyear,&maxyear,keepv=org_npi);
%append(op,revenueonly=N,keepv=org_npi)

%revenue(carrier,line,&minyear,&maxyear,keepv=org_npi);
%append(carrier,revenueonly=Y,keepv=org_npi);

%revenue(hha,revenue,&minyear,&maxyear,keepv=org_npi);
%append(hha,revenueonly=Y,keepv=org_npi);

%revenue(snf,revenue,&minyear,&maxyear,keepv=org_npi);
%append(snf,revenueonly=Y,keepv=org_npi);

data &tempwork..mapreventiveprcdr_&minyear._&maxyear.;
	set &tempwork..mapreventive_carrier_&minyear._&maxyear. &tempwork..mapreventive_hha_&minyear._&maxyear. 
	&tempwork..mapreventive_ip_&minyear._&maxyear. &tempwork..mapreventive_op_&minyear._&maxyear. 
	&tempwork..mapreventive_snf_&minyear._&maxyear.;
	by bene_id clm_thru_dt org_npi clm_typ;
	month=month(clm_thru_dt);
	year=year(clm_thru_dt);
run;

* Getting a monthly count;
proc means data=&tempwork..mapreventiveprcdr_&minyear._&maxyear. noprint nway;
	class year month;
	var awv--anypreventive;
	output out=&outlib..ma_preventiveprcdr1518 (drop=_type_ _freq_) sum()=;
run;

* Getting a beneficiary count;
proc means data=&tempwork..mapreventiveprcdr_&minyear._&maxyear. noprint nway;
	class bene_id year month;
	var awv--anypreventive;
	output out=&outlib..ma_bene_preventiveprcdr1518 (drop=_type_ _freq_) sum()=;
run;

options obs=max;




