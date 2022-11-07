defmodule Person_supervisor do
  @moduledoc """
  Keeps track of all the person pids
  """

  @doc """
  The stateful loop of the person supervisor
  ## Parameters:
  - person_pids: a list with the pids to every Virus_sim.person actor
  - stats: collected stats from unforunate souls who died in a list
  
  ## Messages:
  - {:death_stats, new_stats}: inserts a dead persons stats into the stats list
  - {:insert_pid, pid}: inserts a person to person_pids
  - {:get_r0, pid}: returns the average r0 of every person
  - {:get_time, pid}: returns the average time tick of every person
  - {:send_to_all}: sends a signal to every person, :no_measures | :social_distancing | :lockdown
  """
  def loop(person_pids, stats) do
    receive do
      {:death_stats, new_stats} ->
	loop(person_pids, [new_stats | stats])
      {:insert_pid, pid} ->
	loop([pid | person_pids], stats)
      {:get_r0, pid} ->
	r0 = get_average_r0(person_pids, stats, 0, 0)
	send pid, {:return_r0, r0}
	loop(person_pids, stats)
      {:get_time, pid} ->
	time = get_average_time(person_pids, 0, 0)
	send pid, {:return_time, time}
	loop(person_pids, stats)
      {:send_to_all, signal} ->
	send_to_all(person_pids, signal)
	loop(person_pids, stats)
    end
  end

  @doc """
  Gets the average time of all the people
  ## Parameters:
  - [pid | tail]: pid is the first pid, list is the rest of the pids
  - total_time: accumulated time
  - acc: accumulated amount of alive people
  
  ## Returns:
  - float() the average time among alive people
  """

  def get_average_time([pid], total_time, acc) do
    send pid, {:get_person, self()}
    receive do
      {:return_person, person} ->
	(person.time + total_time)/(acc+1)
    after
      2 ->
	total_time/acc
    end
  end

  def get_average_time([pid | tail], total_time, acc) do
    send pid, {:get_person, self()}
    receive do
      {:return_person, person} ->
	get_average_time(tail, person.time + total_time, acc + 1)
    after
      2 ->
	get_average_time(tail, total_time, acc)
    end
  end
  
  @doc """
  Calculates the average r0 among all people who were ever infected
  ## Parameters:
  - [person_pids]: the remaining list of person pids yet to be calculated
  - stats: the dead list
  - r0_total: accumulative r0 total
  - infected_total: accumulative infected total

  ## Returns:
  - float() average r0, ro_total/infected_total
  """

  def get_average_r0([pid], stats, r0_total, infected_total) do
    send pid, {:get_person, self()}
    receive do
      {:return_person, person} ->
	{r0_total, infected_total} = if person.stats.infected do
	    {r0_total + person.stats.infections, infected_total + 1}
	  else
	    {r0_total, infected_total}
	  end
	{r0_dead, infected_dead} = get_r0_stats_from_dead(stats, 0, 0)
	(r0_total + r0_dead)/(infected_total + infected_dead)
    after
      2 ->
	{r0_dead, infected_dead} = get_r0_stats_from_dead(stats, 0, 0)
	(r0_total + r0_dead)/(infected_total + infected_dead)
    end
  end
  
  def get_average_r0([pid | tail], stats, r0_total, infected_total) do
    send pid, {:get_person, self()}
    receive do
      {:return_person, person} ->
	if person.stats.infected do
	  get_average_r0(tail, stats, r0_total + person.stats.infections, infected_total + 1)
	else
	  get_average_r0(tail, stats, r0_total, infected_total)
	end
    after
      2 ->
	get_average_r0(tail, stats, r0_total, infected_total)
    end
  end

  @doc """
  adds all of the r0's and infected totals from the stats list

  ## Parameters:
  - stats: the dead list
  - r0_total: accumulative r0 total
  - infected_total: accumulative infected total

  ## Returns:
  - {r0_total, infected_total}
  """
  def get_r0_stats_from_dead([], r0_total, infected_total) do
    {r0_total, infected_total}
  end

  def get_r0_stats_from_dead([stat], r0_total, infected_total) do
    if stat.infected do
      {r0_total + stat.infections, infected_total + 1}
    else
      {r0_total, infected_total}
    end
  end

  def get_r0_stats_from_dead([stat | tail], r0_total, infected_total) do
    if stat.infected do
      get_r0_stats_from_dead(tail, r0_total + stat.infections, infected_total + 1)
    else
      get_r0_stats_from_dead(tail, r0_total, infected_total)
    end
  end

  @doc """
  sends a signal to each person in the simulation

  ## Parameters:
  - person_pids: all of the person pids in a list
  - signal: the signal to be sent to the people
  """
  def send_to_all(person_pids, signal) do
    Enum.each(person_pids, fn person ->
      send person, {signal}
    end)
  end
end
