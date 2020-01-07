****************** Load Data with Delimiters *********************;

data wireless_pipe;
	*options missing =.;
	infile 'C:\Users\snasir\Desktop\DSA\SAS\SAS_2\Project\New_Wireless_Pipe.txt' dlm='|' firstobs = 2 dsd; 
	* DSD is most important part;
	length deactreason $4. dealertype $2. Province $2.; 
	* only sprecify variables who do not have default length;
	informat actdt mmddyy10. deactdt mmddyy10. sales dollar8.0; 
	* only put variables who have format other than char or numeric;
	input acctno actdt deactdt deactreason $ goodcredit rateplan dealertype $ AGE Province $ sales; 
	* do not put any details about the format here, only numeric or char;
	label sales='Funds';
	format actdt mmddyy10. deactdt mmddyy10. sales dollar8.2;

run;

******************** Macro to Print N rows of data **************;

%macro mprint(data,obs);
	proc print data=&data(obs=&obs);
	run;
%mend;


*** Understand the Contents of the data ********;

proc contents data = wireless_pipe;
run;

*****  Check if Account Number is unique and also check the population rate of all other variables ******;

proc sql;
	*create table proj.var_info as;
	select count(*)  as Observations, count(distinct(acctno)) as Unique_Account_No
	, count(distinct(dealertype)) as Unique_Dealers
	, count(distinct(province)) as Unique_Provinces, max(age) as Max_Age, min(age) as Min_Age
	, min(actdt) as Min_Active_dt format ddmmyy10., max(actdt) as Max_Active_dt format ddmmyy10.
	, min(deactdt) as Min_DeActive_dt format ddmmyy10., max(deactdt) as Max_DeActive_dt format ddmmyy10.
	, sum(case when dealertype <> '' then 1 else 0 end)*100/count(*) as DealerType_pop
	, sum(case when Province <> '' then 1 else 0 end)*100/count(*) as Province_pop
	, sum(case when actdt <> . then 1 else 0 end)*100/count(*) as actdt_pop
	, sum(case when Sales <> . then 1 else 0 end)*100/count(*) as Sales_pop
	, sum(case when goodcredit <> . then 1 else 0 end)*100/count(*) as goodcredit_pop
	, sum(case when rateplan <> . then 1 else 0 end)*100/count(*) as rateplan_pop
	, sum(case when Age <> . then 1 else 0 end)*100/count(*) as Age_pop
	from wireless_pipe
	;
quit;


**** Check Active and InActive Customers ******;

proc sql;
	select count(actdt) - count(deactdt) as Active , count(deactdt) as InActive
	from wireless_pipe
	;
quit;


******** Plot DeActivation Reason ***********;
title 'De-Activation Reasons';
proc sgplot data=wireless_pipe;
	vbar deactreason/seglabel;
run; 

********** Create Flag for Active Customer *****************;

proc sql;
	create table wireless as
	select *, case when deactdt <> . then 0 else 1 end as Active
	from wireless_pipe
quit;


%mprint(wireless,50);

************* Analysis of Active/InActive Customers By Province ********************;

TITLE "Percentage Of Active and InActive Customers";
proc sgplot data=wireless pctlevel=group;
   vbar province/group=active groupdisplay=cluster stat=percent seglabel;
  title2 "By Province";
run;

proc tabulate data=wireless noseps;
  class province active;
  var acctno;
  table province=' ' all='Total',
        active='Active Status'*acctno=' '*( N='No. of Accounts'*F=comma6.0 pctsum<active>='% of Active')
        /box='Province';
run;


************* Graph of Active/InActive Customers By Age ********************;

proc sort data= wireless;
	by active;
run;

title 'Box Plot for Active Status';
proc boxplot data=wireless;
   plot age*active;
   inset min mean max NOBS /
      header = 'Overall Statistics'
      pos    = tm;
   insetgroup  mean Q2/
      header = 'Statistics by Status';
run;

********* Create Age Groups ***************;

proc format;
  value agefmt
     .       ='Missing'
	 0-12    ='Missing'
     13 -<26 ='13 - 25'
	 26 -<41 ='21 - 40'
	 41 -<51 ='41 - 50'
	 51 -<61 ='51 - 60'
	 61 - high='61+    '
	 ;
run;


******** Analysis of Age Groups **********;


title 'Analysis of Active Status By Age';
proc tabulate data=wireless noseps;
  class age active;
  var acctno;
  format age agefmt.;
  table age=' ' all='Total',
        active='Active Status'*acctno=' '*( N='No. of Accounts'*F=comma6.0 pctsum<active>='% of Active')
        /box='Age Group';
run;


******* Create Sales Groups ********************;

proc format;
  value salesfmt
     0-49       ='0-49'
	 50-99       ='50-99'
	 100 - 199  ='100-199'
     200 - 499  ='200-499'
	 500 - high ='500 and above'
	 ;
run;


title 'Analysis of Sales By Active Status';
proc tabulate data=wireless noseps;
  class sales active;
  var acctno;
  format sales salesfmt.;
  table sales=' ' all='Total',
        active='Active Status'*acctno=' '*( N='No. of Accounts'*F=comma6.0 pctsum<active>='% of Column')
        /box='Sales Group';
run;



******************* Calculate Tenure *****************************;
%let max_active=20/01/2001;
%let date = %sysfunc(inputn(&max_active,ddmmyy10.));
%put   &date ;

proc sql;
	alter table wireless 
	add Tenure num;

	update wireless 
	set tenure =  case when deactdt <>. then intck('day',actdt,deactdt) else intck('day',actdt,&date) end;* format=MMDDYY10.;
quit;
%mprint(wireless,10);


title 'Basic Analysis of Tenure by Credit Standing';
proc means data=wireless maxdec=2 mean min max;
	class goodcredit;
	*format sales salesfmt.;
	var tenure;
run;

proc sort data= wireless;
	by goodcredit;
run;
title 'Box Plot for Tenure by Credit Standing';
proc boxplot data=wireless;
   plot tenure*goodcredit;
   inset min mean max NOBS /
      header = 'Overall Statistics'
      pos    = tm;
   insetgroup  mean Q2='Median'/
      header = 'Statistics by Credit Standing';
run;


************** Monthly DeActivations Status ************;


data wireless_dt;
	set wireless(where=(active=0));
	deact_month=month(deactdt);
	deact_year=year(deactdt);
	deact_cmb=year(deactdt)*100+month(deactdt);
run;

title 'Monthly DeActivations Status';
proc tabulate data = wireless_dt(where=(deact_year<2001));
	class deact_year deact_month;
	var acctno;
	table deact_year=' ' all='Total',
        deact_month='Month'*acctno=' '*( N='No. of Accounts'*F=comma6.0 pctsum<deact_month>='% of Column')
        /box='Timeline';
run;

proc sort data = wireless_dt;
by deact_year;
run;

TITLE "Monthly DeActivations Status";
proc sgplot data=wireless_dt(where=(deact_year<2001)) pctlevel=by;
   vbar deact_month/group=deact_year groupdisplay=cluster stat=percent colorstat=percent seglabel;
   by deact_year;
  title2 "By Month";
run;


**************** Create Tenure Segments  ************************************************;

proc format;
  value tenurefmt
     0 - 29     ='0-29'
	 30 - 59    ='30 - 59'
	 60 - 119   ='60 - 119'
     120 - 179  ='120 - 179'
	 180 - 359  ='180 - 359'
	 360 - high ='360 and above'
	 ;
run;


title 'Analysis of Active Status By Tenure';
proc tabulate data=wireless(where=(tenure<360)) noseps;
  class Tenure active;
  var acctno;
  format tenure tenurefmt.;
  table tenure=' ' all='Total',
        active='Active Status'*acctno=' '*( N='No. of Accounts'*F=comma6.0 pctsum<active>='% of Column')
        /box='Tenure Group';
run;

****** Association between the tenure and Good Credit, RatePlan and DealerType ***************************************************;

title 'Analysis of Rate Plan, Dealer Type and Good Credit';
proc tabulate data=wireless(where=(active=0)) noseps;
  class Tenure dealertype goodcredit rateplan;
  var acctno;
  format tenure tenurefmt.;
  table tenure=' '*( N pctsum<tenure>='% of Column'),
  		dealertype*acctno=' '
		goodcredit*acctno=' '
		rateplan*acctno=' '/box='Tenurees Group';
run;


*********** Analysing which Tenure segment has more tendency to DeActivate ******;

data wireless_tn;
set wireless;
if   0 <tenure<= 29 then tn_grp =  '         0-29';
else if 30 <tenure<= 59 then tn_grp   ='030 - 59';
else if 60 <tenure<= 119 then tn_grp  ='060 - 119';
else if 120 <tenure<= 179 then tn_grp ='120 - 179';
else if 180 <tenure<= 359 then tn_grp ='180 - 359';
else if tenure>= 360 then tn_grp ='360 and above';
run;

%mprint(wireless_tn,10);

proc sort data=wireless_tn;
	by goodcredit;
run;

TITLE "Tenure Analysis";
proc sgplot data=wireless_tn pctlevel=group;
   vbar tn_grp/group=active groupdisplay=stack stat=pct seglabel limitstat=clm;
run;


********** Analysis of Sales against Dealer Type **************************************;


title 'Analysis of Sales against Dealer Type , Good Credit and Rate Plan';
proc tabulate data=wireless(where=(active=0));
  class dealertype goodcredit Rateplan;
  var sales;
  table dealertype=' ',
		Rateplan*goodcredit*sales=' '*( mean)/box=' Dealertype ';
run;


proc sort data=wireless_tn;
	by tn_grp;
run;



