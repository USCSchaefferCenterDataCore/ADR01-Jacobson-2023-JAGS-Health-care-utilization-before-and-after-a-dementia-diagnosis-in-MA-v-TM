/*********************************************************************************************/
title1 'MA/FFS Pilot';

* Author: PF;
* Purpose: Sample including those who switch between FFs and MA;
* Input: quarterly;
* Output: ;

options compress=yes nocenter ls=150 ps=200 errors=5 errorcheck=strict mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

options obs=max;

data &tempwork..switch_2yrwsh1yrv &tempwork..switch_drops_2yrwsh1yrv;
	merge 	sh054066.bene_status_year2015 (keep=bene_id alive_mo_yr enrAB_allyr enrHMO_allyr enrHMO_mo_yr enrFFS_allyr ptd_allyr enrHMO_4_mo_yr
				rename=(enrAB_allyr=enrAB_allyr2015 alive_mo_yr=alive_mo_yr2015 enrHMO_allyr=enrHMO_allyr2015 enrHMO_mo_yr=enrHMO_mo_yr2015 enrFFS_allyr=enrFFS_allyr2015 ptd_allyr=ptd_allyr2015 enrHMO_4_mo_yr=enrHMO_4_mo_yr2015)) 
			sh054066.bene_status_year2016 (keep=bene_id alive_mo_yr enrAB_allyr enrHMO_allyr enrHMO_mo_yr enrFFS_allyr ptd_allyr enrHMO_4_mo_yr
				rename=(enrAB_allyr=enrAB_allyr2016 alive_mo_yr=alive_mo_yr2016 enrHMO_allyr=enrHMO_allyr2016 enrHMO_mo_yr=enrHMO_mo_yr2016 enrFFS_allyr=enrFFS_allyr2016 ptd_allyr=ptd_allyr2016 enrHMO_4_mo_yr=enrHMO_4_mo_yr2016)) 
			sh054066.bene_status_year2017 (keep=bene_id alive_mo_yr anydual anylis age_beg enrAB_allyr enrHMO_allyr enrHMO_mo_yr enrFFS_allyr ptd_allyr enrHMO_4_mo_yr
				rename=(enrAB_allyr=enrAB_allyr2017 alive_mo_yr=alive_mo_yr2017 enrHMO_allyr=enrHMO_allyr2017 enrHMO_mo_yr=enrHMO_mo_yr2017 enrFFS_allyr=enrFFS_allyr2017 ptd_allyr=ptd_allyr2017 enrHMO_4_mo_yr=enrHMO_4_mo_yr2017)) 
			sh054066.bene_status_year2018 (keep=bene_id alive_mo_yr enrAB_allyr enrHMO_allyr enrHMO_mo_yr enrFFS_allyr ptd_allyr enrHMO_4_mo_yr
				rename=(enrAB_allyr=enrAB_allyr2018 alive_mo_yr=alive_mo_yr2018 enrHMO_allyr=enrHMO_allyr2018 enrHMO_mo_yr=enrHMO_mo_yr2018 enrFFS_allyr=enrFFS_allyr2018 ptd_allyr=ptd_allyr2018 enrHMO_4_mo_yr=enrHMO_4_mo_yr2018)) 
			sh054066.bene_demog2020 (keep=bene_id birth_date death_date race_bg sex)

			&outlib..dxmciincv1yrv_scendx_ffs (in=r keep=bene_id scen_dx_inc2015-scen_dx_inc2017 
				rename=(scen_dx_inc2015=ffs_plwd_inc_2015 scen_dx_inc2016=ffs_plwd_inc_2016 scen_dx_inc2017=ffs_plwd_inc_2017))
			mbsf.mbsf_cc_2016 (in=e keep=bene_id ami atrial_fib diabetes hypert hyperl stroke_tia
				rename=(ami=ffs_ami atrial_fib=ffs_atf diabetes=ffs_diabetes hypert=ffs_hypert hyperl=ffs_hyperl stroke_tia=ffs_strketia))
			&tempwork..bene_arthglua_ffs (in=e keep=bene_id first_arthglau rename=(first_arthglau=ffs_first_arthglau))
			base.ltc2015_bene (in=l rename=(ptd2015=ffs_ptd2015 pos2015=ffs_pos2015 prcdr2015=ffs_prcdr2015))
			base.ltc2016_bene (in=m rename=(ptd2016=ffs_ptd2016 pos2016=ffs_pos2016 prcdr2016=ffs_prcdr2016))
			base.ltc2017_bene (in=n rename=(ptd2017=ffs_ptd2017 pos2017=ffs_pos2017 prcdr2017=ffs_prcdr2017))
			base.ltc2018_bene (in=o rename=(ptd2018=ffs_ptd2018 pos2018=ffs_pos2018 prcdr2018=ffs_prcdr2018))

			&outlib..dxmciincv1yrv_scendx_ma (in=q keep=bene_id scen_dx_inc2015-scen_dx_inc2017 
				rename=(scen_dx_inc2015=ma_plwd_inc_2015 scen_dx_inc2016=ma_plwd_inc_2016 scen_dx_inc2017=ma_plwd_inc_2017))
			&tempwork..bene_arthglua_ma (in=s keep=bene_id first_arthglau rename=(first_arthglau=ma_first_arthglau))
			&tempwork..bene_diabetes_mainc (in=t keep=bene_id ccw_diab rename=(ccw_diab=ma_diabetes))
			&tempwork..bene_hyperl_mainc (in=u keep=bene_id ccw_hyperl rename=(ccw_hyperl=ma_hyperl))
			&tempwork..bene_hypert_mainc (in=v keep=bene_id ccw_hypert rename=(ccw_hypert=ma_hypert))
			&tempwork..bene_strketia_mainc (in=w keep=bene_id ccw_strketia rename=(ccw_strketia=ma_strketia))
			&tempwork..bene_ami_mainc (in=x keep=bene_id ccw_ami rename=(ccw_ami=ma_ami))
			&tempwork..bene_atf_mainc (in=y keep=bene_id ccw_atf rename=(ccw_atf=ma_atf))
		  	base.ma_ltc2015_bene (in=z rename=(ptd15=ma_ptd2015 pos15=ma_pos2015 prcdr15=ma_prcdr2015))
	      	base.ma_ltc2016_bene (in=aa rename=(ptd16=ma_ptd2016 pos16=ma_pos2016 prcdr16=ma_prcdr2016))
			base.ma_ltc2017_bene (in=ab rename=(ptd17=ma_ptd2017 pos17=ma_pos2017 prcdr17=ma_prcdr2017))
			base.ma_ltc2018_bene (in=ac rename=(ptd18=ma_ptd2018 pos18=ma_pos2018 prcdr18=ma_prcdr2018));
		by bene_id;


		* identify all people who have been in the sample from 2015-2018;
		array enrAB_allyr [2015:2018] $ enrAB_allyr2015-enrAB_allyr2018;
		array ptd_allyr [2015:2018] $ ptd_allyr2015-ptd_allyr2018;
		array enrFFS_allyr [2015:2018] $ enrFFS_allyr2015-enrFFS_allyr2018;
		array enrHMO_mo_yr [2015:2018] enrHMO_mo_yr2015-enrHMO_mo_yr2018;
		array enrhmo_4_mo_yr [2015:2018] enrHMO_4_mo_yr2015-enrHMO_4_mo_yr2018;

		deathyr=year(death_date);

		* throw out everyone who's dead or under 67 in 2017;
		if .<deathyr<2017 or age_beg<67 then delete;

		* Define sample as those who have are enrolled in Parts A, B, and D all eligible months from 2015 until death;
		ptd=1;
		samp=0;
		enr=1;

		do yr=2015 to min(2018,deathyr);
			if ptd_allyr[yr] ne 'Y' then ptd=0;
			if (enrFFS_allyr[yr]='N' and enrHmo_mo_yr{yr]=0) or enrFFS_allyr[yr]="" or enrHMO_mo_yr[yr]=. then enr=0;
			if enrHMO_4_mo_yr[yr]>0 then enr=0;
		end;

		if ptd=1 and enr=1 then samp=1;

		* Define FFS or HMO based on what they are in 2017 (year of dx);
		if samp and age_beg>=67 then do;
			ffs=0;
			ma=0;
			if enrFFS_allyr2017='Y' then ffs=1;
			if enrHMO_mo_yr2017>0 then ma=1;
		end;

		* Combining FFS and MA information;
		plwd_inc_2015=min(ffs_plwd_inc_2015,ma_plwd_inc_2015);
		plwd_inc_2016=min(ffs_plwd_inc_2016,ma_plwd_inc_2016);
		plwd_inc_2017=min(ffs_plwd_inc_2017,ma_plwd_inc_2017);
		first_arthglau=min(ffs_first_arthglau,ma_first_arthglau);

	* Use both FFS and MA information to identify incident PLWD and arthritis/glaucoma;
 	if plwd_inc_2015=. and plwd_inc_2016=. then do;
		incplwd=0;
		if plwd_inc_2017 ne . then do;
			incplwd=1;
			ageincplwd=intck('year',birth_date,plwd_inc_2017,'C');
		end;
	end;

	if incplwd=0 and (first_arthglau=. or year(first_arthglau)>=2017) then do;
		incarthglau=0;
		if year(first_arthglau)=2017 then do;
			incarthglau=1;
			ageincarthglau=intck('year',birth_date,first_arthglau,'C');
		end;
	end;

	* sample characteristics;
	diabetes=(ffs_diabetes in(1,3)); diabetes=max(diabetes,ma_diabetes);
	hypert=(ffs_hypert in(1,3)); hypert=max(hypert,ma_hypert);
	hyperl=(ffs_hyperl in(1,3)); hyperl=max(hyperl,ma_hyperl);
	strketia=(ffs_strketia in(1,3)); strketia=max(strketia,ma_strketia);
	ami=(ffs_ami in(1,3)); ami=max(ami,ma_ami);
	atf=(ffs_atf in(1,3)); atf=max(atf,ma_atf);

	female=(sex="2");

	race_dw=(race_bg="1" );
	race_db=(race_bg="2" );
	race_dh=(race_bg="5" );
	race_da=(race_bg="4" );
	race_dn=(race_bg="6" );
	race_do=(race_bg="3" );

	age_lt75=(age_beg<75);
	age_7584=(75<=age_beg<=84);
	age_ge85=(age_beg>84);

	dual=(anydual="Y");
	lis=(anylis="Y");

	cc_diab=(diabetes=1);
	cc_hypert=(hypert=1);
	cc_hyperl=(hyperl=1);
	cc_str=(strketia=1);
	cc_ami=(ami=1);
	cc_atf=(atf=1);

	format first_arthglau mmddyy10.;

	* drop anyone who was in an ltc anytime in 2015-2018;
	if ffs then ltc=max(of ffs_ptd2015-ffs_ptd2018,of ffs_pos2015-ffs_pos2018,of ffs_prcdr2015-ffs_prcdr2018);
	if ma then ltc=max(of ma_ptd2015-ma_ptd2018,of ma_pos2015-ma_pos2018,of ma_prcdr2015-ma_prcdr2018);

	first_adrddx=plwd_inc_2017;
	format first_adrddx mmddyy10.;

	* drop anyone who died prior to plwd or arthritis/glaucoma;
	if incplwd=1 and .<death_date<first_adrddx then death_drop=1;
	if incarthglau=1 and .<death_date<first_arthglau then death_drop=1;

	if ltc=1 or samp=0 or death_drop=1 then output &tempwork..switch_drops_2yrwsh1yrv;
	else output &tempwork..switch_2yrwsh1yrv;
run;

* Checking for missing values;
proc univariate data=&tempwork..switch_2yrwsh1yrv outtable=&tempwork..switch_2yrwsh1yrv_univar; run;

* Check that it's either ffs or ma;
proc freq data=&tempwork..switch_2yrwsh1yrv noprint;
	table ffs*ma / out=&tempwork..ffsmack missing;
run;

* Checking our final sample to with original to see how many are switchers;
proc sort data=&outlib..ma_samp_2yrwsh1yrv out=&tempwork..ma_samp_2yrwsh1yrv; by bene_id; run;

data &tempwork..switch_2yrwsh1yrv_ck;
	merge &tempwork..switch_2yrwsh1yrv (in=a keep=bene_id ffs ma female race_d: age_lt75 age_7584 age_ge85 dual lis incplwd incarthglau cc:) &outlib..ffs_samp_2yrwsh1yrv (in=b keep=bene_id) &tempwork..ma_samp_2yrwsh1yrv (in=c keep=bene_id);
	by bene_id;

	switch=a;
	ogffs=b;
	ogma=c;
	if switch=1 then switcher=(ogffs ne 1 and ogma ne 1);

run;

proc freq data=&tempwork..switch_2yrwsh1yrv_ck noprint;
	table switch*ogffs*ogma / out=&tempwork..switch_ogck missing;
	table ffs*ogffs / out=&tempwork..ogffsck missing;
	table ma*ogma / out=&tempwork..maffsck missing;
run;

proc freq data=&tempwork..switch_2yrwsh1yrv_ck noprint;
	table switcher*switch*ogffs*ogma / out=&tempwork..switcher_ogck missing;
run;

/* Export Macro */
%macro exportswitch(data);
proc export data=&tempwork..&data.
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/sample_switchers_1518_2yrwsh1yrv.xlsx"
	dbms=xlsx
	replace;
	sheet="&data.";
run;
%mend;

proc means data=&tempwork..switch_2yrwsh1yrv_ck noprint nway;
	class switcher;
	var female race_d: age_lt75 age_7584 age_ge85 dual lis incplwd incarthglau cc:;
	output out=&tempwork..switcher_stats sum()= mean()= / autoname;
run;
%exportswitch(switcher_stats);


/* Stats */
proc univariate data=&tempwork..switch_2yrwsh1yrv noprint outtable=&tempwork..switchinc_age_2yrwsh1yrv;
	class ffs;
	var ageinc:;
run;
%exportswitch(switchinc_age_2yrwsh1yrv);

proc means data=&tempwork..switch_2yrwsh1yrv noprint nway;
	class ffs;
	var female race_d: age_lt75 age_7584 age_ge85 dual lis incplwd incarthglau cc:;
	output out=&tempwork..switch_stats_2yrwsh1yrv sum()= mean()= / autoname;
run;
%exportswitch(switch_stats_2yrwsh1yrv);
	
proc means data=&tempwork..switch_2yrwsh1yrv noprint nway;
	where incplwd=1;
	class ffs;
	var female race_d: age_lt75 age_7584 age_ge85 dual lis incplwd  incarthglau cc:;
	output out=&tempwork..switch_plwd_stats_2yrwsh1yrv sum()= mean()= / autoname;
run;
%exportswitch(switch_plwd_stats_2yrwsh1yrv);

proc means data=&tempwork..switch_2yrwsh1yrv noprint nway;
	where incarthglau=1;
	class ffs;
	var female race_d: age_lt75 age_7584 age_ge85 dual lis incplwd  incarthglau cc:;
	output out=&tempwork..switch_arthglau_2yrwsh1yrv sum()= mean()= / autoname;
run;
%exportswitch(switch_arthglau_2yrwsh1yrv);

/* Stats Age-Adj to match FFS */
proc freq data=&tempwork..switch_2yrwsh1yrv noprint;
	where ffs;
	table age_beg / out=&tempwork..switch_agedist_ffs (drop=count rename=percent=pct_ffs);
run;

proc freq data=&tempwork..switch_2yrwsh1yrv noprint;
	where ma;
	table age_beg / out=&tempwork..switch_agedist_ma (keep=age_beg count);
run;

data &tempwork..switch_age_weight;
	merge &tempwork..switch_agedist_ffs (in=a) &tempwork..switch_agedist_ma (in=b);
	by age_beg;
	weight=(pct_ffs/100)/count;
run;

proc sort data=&tempwork..switch_age_weight out=&tempwork..switch_age_weight_s; by age_beg; run;

proc sort data=&tempwork..switch_2yrwsh1yrv out=&tempwork..ma_switch_2yrwsh1yrv; where ffs=0; by age_beg; run;

data &tempwork..ma_switchw_2yrwsh1yrv;
	merge &tempwork..ma_switch_2yrwsh1yrv (in=a) &tempwork..switch_age_weight_s (in=b);
	by age_beg;
	if a;
run;

proc means data=&tempwork..ma_switchw_2yrwsh1yrv noprint nway;
	weight weight;
	var incplwd  incarthglau cc:;
	output out=&tempwork..ma_switchw_stats_2yrwsh1yrv mean()= sum()= / autoname;
run;
%exportswitch(ma_switchw_stats_2yrwsh1yrv);









			
