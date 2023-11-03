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
%let minyear=2015;
%let maxyear=2018;
%let maxdx=26;

options obs=max;

%macro getdx(ctyp,byear,eyear,dxv=,dropv=,keepv=,byvar=);
	%do year=&byear %to &eyear;
		data &tempwork..arthglaudx_&ctyp._&year;
		
			set 
				
			%if &year<&demogvq %then %do;
				%do mo=1 %to 12;
					%if &mo<10 %then %do;
						rif&year..&ctyp._claims_0&mo (keep=bene_id clm_thru_dt icd_dgns_cd: &dxv &keepv drop=&dropv)
					%end;
					%else %if &mo>=10 %then %do;
						rif&year..&ctyp._claims_&mo (keep=bene_id clm_thru_dt icd_dgns_cd: &dxv &keepv drop=&dropv)
					%end;
				%end;
			%end;
			%else %if &year>=&demogvq %then %do;
				%do mo=1 %to 12;
					%if &mo<10 %then %do;
						rifq&year..&ctyp._claims_0&mo (keep=bene_id clm_thru_dt icd_dgns_cd: &dxv &keepv drop=&dropv)
					%end;
					%else %if &mo>=10 %then %do;
						rifq&year..&ctyp._claims_&mo (keep=bene_id clm_thru_dt icd_dgns_cd: &dxv &keepv drop=&dropv)
					%end;
				%end;
			%end;
			;
			by bene_id &byvar;

		length arthglaudx1-arthglaudx&maxdx $ 5;
		
		* Count how many dementia-related dx are found, separately by ccw list and other list;
		*	Keep thru_dt as dx_date;
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
    else if "%substr(&ctyp,1,1)" = "b" then clm_typ="5"; /* carrier */
    else clm_typ="X";  
    
		drop icd_dgns_cd: &dxv clm_thru_dt i j;
		rename dxsub=dx_max;
      
run;	
%if %upcase(&ctyp) ne BCARRIER %then %do;
proc sort data=&tempwork..arthglaudx_&ctyp._&year; by bene_id year arthglaudx_dt clm_typ; run;
%end;
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

%getdx(bcarrier,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,keepv=clm_id,byvar=clm_id);

%getdx(hha,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,
			 keepv=clm_id);		
%appenddx(hha);
		
%getdx(inpatient,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,
			 keepv=clm_id);	
%appenddx(inpatient);
		
%getdx(outpatient,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,
			 keepv=clm_id);	
%appenddx(outpatient);

%getdx(snf,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,
			 keepv=clm_id);
%appenddx(snf);

* Car line diagnoses;
%macro carline(byear,eyear);
%do year=&byear %to &eyear;
data &tempwork..arthglaudx_carline_&year;
		set 
			%if &year<&demogvq %then %do;
				%do mo=1 %to 12;
					%if &mo<10 %then %do;
						rif&year..bcarrier_line_0&mo (keep=bene_id clm_thru_dt line_icd_dgns_cd clm_id)
					%end;
					%if &mo>=12 %then %do;
						rif&year..bcarrier_line_&mo (keep=bene_id clm_thru_dt line_icd_dgns_cd clm_id) 
					%end;
				%end;
			%end;
			%else %if &year>=&demogvq %then %do;
				%do mo=1 %to 12;
					%if &mo<10 %then %do;
						rifq&year..bcarrier_line_0&mo (keep=bene_id clm_thru_dt line_icd_dgns_cd clm_id)
					%end;
					%if &mo>=12 %then %do;
						rifq&year..bcarrier_line_&mo (keep=bene_id clm_thru_dt line_icd_dgns_cd clm_id) 
					%end;
				%end;
			%end;				
				;
		by bene_id clm_id;

		length linedx 3;
		length clm_typ $1 line_dxtype $1;
		
		year=year(clm_thru_dt);
		
		linedx=line_icd_dgns_cd in(&arthritis,&glaucoma);

		if linedx=0 then delete;
		arthglaudx_dt=clm_thru_dt;
		clm_typ="6";
      
		drop clm_thru_dt;
run;
data &tempwork..arthglaudx_carmrg_&year;
		merge &tempwork..arthglaudx_bcarrier_&year (in=_inclm drop=year)
			  &tempwork..arthglaudx_carline_&year  (in=_inline rename=(arthglaudx_dt=linedx_dt));
		by bene_id clm_id;

		infrom=10*_inclm+_inline;
		
		length n_found n_added matchdt _maxdx in_line 3;
		length _arthglaudx1-_arthglaudx&maxdx $ 5;
		retain n_found n_added matchdt _maxdx in_line _arthglaudx1-_arthglaudx&maxdx _arthglaudx_dt;
		
		array arthglaudx [*] arthglaudx1-arthglaudx&maxdx;
		array _arthglaudx [*] _arthglaudx1-_arthglaudx&maxdx;
		
		if first.clm_id then do;
				n_found=0;
				n_added=0;
				matchdt=0;
				if _inclm=1 then _maxdx=dx_max;
				else _maxdx=0;
				in_line=0;
				do i=1 to dim(arthglaudx);
					_arthglaudx[i]=arthglaudx[i];
				end;
				if _inclm then _arthglaudx_dt=arthglaudx_dt;
				else _arthglaudx_dt=linedx_dt;
		end;
		
		if clm_typ="" then clm_typ="5"; * treat linedx source as car;
		
		if _inline=1 then in_line=in_line+1; * count how many lines merge to a claim;
			
		if _inline then do; * if in line file then keeping track of new diagnoses;
			line_found=0;
			do i=1 to _maxdx;
				if line_icd_dgns_cd=_arthglaudx[i] then line_found=1;
			end;
			if line_found=1 then do; * keep track of codes found on base file;
				n_found=n_found+1;
				matchdt=matchdt+(linedx_dt=arthglaudx_dt);
			end;
			else do; * add unfound code;
				_maxdx=_maxdx+1;
				if 0<_maxdx<=&maxdx then _arthglaudx[_maxdx]=line_icd_dgns_cd;
				n_added=n_added+1;
				if infrom=11 then matchdt=matchdt+(linedx_dt=arthglaudx_dt);
				else if infrom=1 then _arthglaudx_dt=linedx_dt;
			end;	
		
    end;

	if last.clm_id then do;
			dx_max=_maxdx;
			do i=1 to dim(arthglaudx);
				arthglaudx[i]=_arthglaudx[i];
			end;
			arthglaudx_dt=_arthglaudx_dt;
			year=year(arthglaudx_dt);
			output;
	end;
	
	drop line_icd_dgns_cd line_dxtype _maxdx i _arthglaudx:;
	format linedx_dt arthglaudx_dt mmddyy10.;
	
run;
proc sort data=&tempwork..arthglaudx_carmrg_&year; by bene_id year arthglaudx_dt clm_typ; run;
%end;
%mend;

%carline(&minyear,&maxyear);
%appenddx(carmrg);

data &tempwork..arthglau_dx_&minyear._&maxyear.;
		
		merge &tempwork..arthglaudx_inpatient_&minyear._&maxyear 
			  &tempwork..arthglaudx_outpatient_&minyear._&maxyear
			  &tempwork..arthglaudx_snf_&minyear._&maxyear 
			  &tempwork..arthglaudx_hha_&minyear._&maxyear 
			  &tempwork..arthglaudx_carmrg_&minyear._&maxyear;
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

proc means data=&tempwork..arthglau_dx_&minyear._&maxyear. noprint nway;
	class bene_id arthglaudx_dt;
	var ip snf op hha car;
	output out=&tempwork..ffs_arthglaudt (drop=_type_ _freq_) max(ip snf op hha car)=;
run;

proc means data=&tempwork..ffs_arthglaudt noprint nway;
	class bene_id;
	var arthglaudx_dt ip snf op hha car;
	output out=&tempwork..bene_arthglua_ffs (drop=_type_ _freq_) min(arthglaudx_dt)=first_arthglau sum(ip snf op hha car)=;
run;

/*proc datasets library=&tempwork kill; run; quit;*/
options obs=max;

		
		
		
		
		
			
