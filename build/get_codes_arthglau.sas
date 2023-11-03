/*********************************************************************************************/
title1 'MA FFS Pilot';

* Author: PF;
* Purpose: Get all dx codes for arthritis and glaucoma;
* Input: CC_codes.csv; 
* Output: macro for arthritis codes and gluacoma codes;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

options obs=max;
data cc_codes;
	infile "&rootpath./Projects/Programs/chronic_conditions_package/csv_input/CC_Codes.csv" dlm="2c"x dsd lrecl=32767 missover firstobs=2;
	informat
		Condition  $10.
		CodeType	$10.
		DxCodeLocation $8.
		DxCode $10.;
	format
		Condition $10.
		CodeType	$10.
		DxCodeLocation	$8.
		DxCode $10.;
	input
		Condition $
		CodeType $
		DxCodeLocation $
		DxCode $;
run;

data cc_codes1;
	set cc_codes;
	if condition in('RAOA','GLAUCOMA');
run;

proc sort data=cc_codes1; by condition codetype; run;

		data cc_codes2;
			set cc_codes1;
			by condition;
			format dxcode2 $8. allcodes $12000.;
			if first.condition then allcodes="";
			retain allcodes;
			period=index(trim(left(dxcode)),".");
			dxcode2=upcase(trim(left(compress(dxcode,"."))));
			* Adjusting to compensate for any incorrectly formatted numeric codes due to CSV format;
			if length(trim(left(dxcode2)))=4 & CodeType="ICD9DX" & period=4 then dxcode2=trim(left(dxcode2))||"0";
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9DX" & period=4 then dxcode2=trim(left(dxcode2))||"00";
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9DX" & period=2 then dxcode2="0"||trim(left(dxcode2))||"0";
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9DX" & period=0 then dxcode2=trim(left(dxcode2))||"00";
			if length(trim(left(dxcode2)))=2 & CodeType="ICD9DX" & period=0 then dxcode2="0"||trim(left(dxcode2))||"00";
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9PRCDR" & period=2 then  dxcode2="0"||trim(left(dxcode2));
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9PRCDR" & period=3 then dxcode2=trim(left(dxcode2))||"0";
			if codetype="HCPCS" and dxcode ne "" then do;
				if length(dxcode2)=1 then dxcode2="0000"||dxcode2;
				if length(dxcode2)=2 then dxcode2="000"||dxcode2;
				if length(dxcode2)=3 then dxcode2="00"||dxcode2;
				if length(dxcode2)=4 then dxcode2="0"||dxcode2;
			end;
			* Creating a concatenated list of all codes by condition and code type;
			allcodes=catx('","',allcodes,dxcode2);
			if last.condition;

			if condition="GLAUCOMA" then call symput('glaucoma',compress(allcodes));
			if condition='RAOA' then call symput('arthritis',compress(allcodes));
		run;

%let glaucoma="&glaucoma.";
%let arthritis="&arthritis.";
%put(&glaucoma);
%put(&arthritis);
%let extraarth="M057A","M058A","M060A","M068A","M080A","M082A","M084A","M089A","M1909","M1919";
%let arthritis=&arthritis.,&extraarth;
%put(&arthritis);
