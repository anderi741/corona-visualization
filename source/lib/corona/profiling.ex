defmodule Virus_sim_prof do
  import ExProf.Macro
  
  @doc "analyze with profile macro"
  def do_analyze do
    profile do
      :timer.sleep 2000
      Virus_sim.init(10000, 100, {4, 8}, {10, 40})
    end
  end

  @doc "get analysis records and sum them up"
  def run do
    {records, _block_result} = do_analyze()
    total_percent = Enum.reduce(records, 0.0, &(&1.percent + &2))
    IO.inspect "total = #{total_percent}"
  end
  
  end
