drop procedure if exists NHL_Prediction;

delimiter $
create procedure NHL_Prediction(v_max int, testsize double)
begin

# Declare/set v_counter to v_min. 
declare v_counter int unsigned default 1;

# Truncate the output table from the previous call. 
  truncate NHL_Prediction_Output;
  start transaction;
  
# Run the function as long as v_counter is less than or equal to v_max. 
  while v_counter <= v_max do
	
# Create the random test-set using the RAND function. 
    Create table NHL_temp select *, CASE when RAND()<=testsize then 'Test' else 'Result' END as Dataset
	from NHL_Prediction_Test;

# Calculate the Team data for each team at 5v5 and All strengths using Group By. 
	Create table NHL_Temp1 select Season, Team, '5v5' as StrengthState, 
	SUM(CASE when Dataset='Test' then Goal else 0 END) as GF_Test,
    SUM(CASE when Dataset='Result' then Goal else 0 END) as GF_Result, 
    SUM(CASE when Dataset='Test' then xG_F else 0 END) as xGF_Test, 
    SUM(CASE when Dataset='Result' then xG_F else 0 END) as xGF_Result,
    SUM(CASE when Dataset='Test' then Fenwick else 0 END) as FF_Test, 
    SUM(CASE when Dataset='Result' then Fenwick else 0 END) as FF_Result
	from NHL_temp
    where StrengthState='5v5'
    Group by Season, Team
	UNION
	select Season, Team, 'All' as StrengthState, 
	SUM(CASE when Dataset='Test' then Goal else 0 END) as GF_Test,
    SUM(CASE when Dataset='Result' then Goal else 0 END) as GF_Result, 
    SUM(CASE when Dataset='Test' then xG_F else 0 END) as xGF_Test, 
    SUM(CASE when Dataset='Result' then xG_F else 0 END) as xGF_Result,
    SUM(CASE when Dataset='Test' then Fenwick else 0 END) as FF_Test, 
    SUM(CASE when Dataset='Result' then Fenwick else 0 END) as FF_Result
	from NHL_temp
    Group by Season, Team;

# Calculate the Team data against each team at 5v5 and All strengths using Group By. 
	Create table NHL_Temp2 select Season, Opponent as Team, '5v5' as StrengthState, 
	SUM(CASE when Dataset='Test' then Goal else 0 END) as GA_Test,
    SUM(CASE when Dataset='Result' then Goal else 0 END) as GA_Result, 
    SUM(CASE when Dataset='Test' then xG_F else 0 END) as xGA_Test, 
    SUM(CASE when Dataset='Result' then xG_F else 0 END) as xGA_Result,
    SUM(CASE when Dataset='Test' then Fenwick else 0 END) as FA_Test, 
    SUM(CASE when Dataset='Result' then Fenwick else 0 END) as FA_Result
	from NHL_temp
    where StrengthState='5v5'
    Group by Season, Opponent
	UNION
	select Season, Opponent as Team, 'All' as StrengthState, 
	SUM(CASE when Dataset='Test' then Goal else 0 END) as GA_Test,
    SUM(CASE when Dataset='Result' then Goal else 0 END) as GA_Result, 
    SUM(CASE when Dataset='Test' then xG_F else 0 END) as xGA_Test, 
    SUM(CASE when Dataset='Result' then xG_F else 0 END) as xGA_Result,
    SUM(CASE when Dataset='Test' then Fenwick else 0 END) as FA_Test, 
    SUM(CASE when Dataset='Result' then Fenwick else 0 END) as FA_Result
	from NHL_temp
    Group by Season, Opponent;

# The results are inserted into the output table. 
	Insert into NHL_Prediction_Output select s1.Season, s1.Team, s1.StrengthState, 
	GF_Test, GF_Result, GA_Test, GA_Result, 
    xGF_Test, xGF_Result, xGA_Test, xGA_Result, 
    FF_Test, FF_Result, FA_Test, FA_Result, v_counter as Simulation
	from NHL_Temp1 as s1
    left join NHL_Temp2 as s2
		on s1.Season=s2.Season and s1.Team=s2.Team and s1.StrengthState=s2.StrengthState;

# The temp tables are dropped before the next loop. 
	drop table NHL_temp;
	drop table NHL_temp1;
	drop table NHL_temp2;
    
# Add +1 to the v_counter.
    set v_counter=v_counter+1;
  end while;
  commit;
end $

delimiter ;