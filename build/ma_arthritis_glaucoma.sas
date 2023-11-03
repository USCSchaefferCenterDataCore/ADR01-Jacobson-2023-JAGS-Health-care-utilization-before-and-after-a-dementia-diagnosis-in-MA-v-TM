/*********************************************************************************************/
title1 'Exploring AD Incidence Definition';

* Author: PF;
* Purpose: Pulling all claim dates with dementia diagnosis, keeping diagnosis info and 
					 diagnosing physician info;
* Input: Pull dementia claims; 
* Output: dementia_dx_[ctyp]_2001_&maxyear., dementia_carmrg_2001_&maxyear., dementia_dxdt_2001_&maxyear.;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

**%include "header.sas";

***** Years/Macro Variables;
%let minyear=15;
%let maxyear=18;
%let maxdx=26;

options obs=max;

%macro getdx(ctyp,byear,eyear,dxv=,dropv=,keepv=clm_cntl_num clm_freq_cd clm_mdcl_rec,byvar=);
	%do year=&byear %to &eyear;
		data &tempwork..arthglaudx_&ctyp._&year;
		
			set enrfpl&year..&ctyp._base_enc (keep=bene_id clm_thru_dt icd_dgns_cd: &dxv &keepv drop=&dropv)
			;
			by bene_id &byvar;

		length arthglaudx1-arthglaudx&maxdx $ 5;
		
		* Count how many dementia-related dx are found, separately by ccw list and other list;
		* Keep thru_dt as dx_date;
		* Keep first 5 dx codes found;
		
		array diag [*] icd_dgns_cd: &dxv;
		array arthglaudx [*] arthglaudx1-arthglaudx&maxdx;
		
		year=year(clm_thru_dt);
		
		ndx=0;
		dxsub=0;
		
		do i=1 to dim(diag);
			if diag[i] in(&arthritis,&glaucoma) then ndx=ndx+1; * Counting total number of arthglau diagnoses;
			if diag[i] in (&arthritis,&glaucoma) then do; 
				found=0;
				do j=1 to dxsub;
					if diag[i]=arthglaudx[j] then found=j;
				end;
				if found=0 then do;
					dxsub=dxsub+1;
					if dxsub<=&maxdx then arthglaudx[dxsub]=diag[i];
				end;
			end;
		end;
		
		if ndx=0 then delete;
		else arthglaudx_dt=clm_thru_dt;
       
    length clm_typ $1;
    
    if "%substr(&ctyp,1,1)" = "i" then clm_typ="1"; /* inpatient */
    else if "%substr(&ctyp,1,1)" = "s" then clm_typ="2"; /* SNF */
    else if "%substr(&ctyp,1,1)" = "o" then clm_typ="3"; /* outpatient */
    else if "%substr(&ctyp,1,1)" = "h" then clm_typ="4"; /* home health */
    else if "%substr(&ctyp,1,1)" = "c" then clm_typ="5"; /* carrier */
    else clm_typ="X";  
    
		drop icd_dgns_cd: &dxv clm_thru_dt i j;
		rename dxsub=dx_max;
      
run;	

proc sort data=&tempwork..arthglaudx_&ctyp._&year; by bene_id year arthglaudx_dt clm_typ; run;

%end;
%mend getdx;

%macro appenddx(ctyp);
	
data &tempwork..arthglaudx_&ctyp._&minyear._&maxyear;
		set 
	%do year=&minyear %to &maxyear;
		&tempwork..arthglaudx_&ctyp._&year
	%end; ;
	by bene_id year arthglaudx_dt clm_typ;
run;

%mend;

%getdx(carrier,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,keepv=clm_cntl_num clm_freq_cd clm_mdcl_rec,byvar=);
%appenddx(carrier);

%getdx(hha,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,
			 keepv=clm_cntl_num clm_freq_cd clm_mdcl_rec);		
%appenddx(hha);
		
%getdx(ip,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,
			 keepv=clm_cntl_num clm_freq_cd clm_mdcl_rec);	
%appenddx(ip);
		
%getdx(op,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,
			 keepv=clm_cntl_num clm_freq_cd clm_mdcl_rec);	
%appenddx(op);

%getdx(snf,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,
			 keepv=clm_cntl_num clm_freq_cd clm_mdcl_rec);
%appenddx(snf);

%let minyear=15;
%let maxyear=18;
%let maxdx=26;
data &tempwork..arthglau_dx_&minyear._&maxyear.;
		
		merge &tempwork..arthglaudx_ip_&minyear._&maxyear 
			  &tempwork..arthglaudx_op_&minyear._&maxyear
			  &tempwork..arthglaudx_snf_&minyear._&maxyear 
			  &tempwork..arthglaudx_hha_&minyear._&maxyear 
			  &tempwork..arthglaudx_carrier_&minyear._&maxyear;
		by bene_id year arthglaudx_dt clm_typ;

		array arth [*] arthglaudx1-arthglaudx26;

		arthritis=0;
		glaucoma=0;
		do i=1 to dim(arth);
			if arth[i] in(&arthritis) then arthritis=1;
			if arth[i] in(&glaucoma) then glaucoma=1;
		end;

		ip=0;
		snf=0;
		op=0;
		hha=0;
		car=0;

		if find(clm_typ,"1") then ip=1;
		if find(clm_typ,"2") then snf=1;
		if find(clm_typ,"3") then op=1;
		if find(clm_typ,"4") then hha=1;
		if find(clm_typ,"5") then car=1;
				
run;

/*proc datasets library=&tempwork kill; run; quit;*/
options obs=max;

		
		
		
		
		
			
