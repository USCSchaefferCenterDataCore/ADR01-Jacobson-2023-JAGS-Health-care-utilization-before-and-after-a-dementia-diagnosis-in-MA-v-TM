/*********************************************************************************************/
title1 'LTC';

* Author: PF;
* Purpose: Pull LTC POS Codes from carrier file;
* Input: CAR;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

options obs=max;
%let minyear=15;
%let maxyear=18;

%macro pos(byear,eyear);
%do year=&byear %to &eyear;
data &tempwork..ltc_pos_carline_&year;
		set enrfpl&year..carrier_line_enc (keep=bene_id clm_thru_dt line_place_of_srvc_cd);
		by bene_id;

		if line_place_of_srvc_cd in("30","31","32","33","32");
	
run;
%end;
%mend;
%pos(&minyear,&maxyear);
