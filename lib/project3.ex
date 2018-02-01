defmodule Project3 do
  use GenServer

  @name :master
  @base 4

  def handle_cast(:begin_protocol, state) do
    {no_of_nodes, _, no_of_reqs, no_joined, no_routed, no_hops} = state
    no_bits = Float.ceil(:math.log(no_of_nodes)/:math.log(@base))
    no_bits = round(no_bits)
    node_id_space = round(Float.ceil(:math.pow(@base, no_bits)))
    no_nodes_first_group = if(no_of_nodes <= 1024) do no_of_nodes else 1024 end
    random_List = Enum.shuffle(Enum.to_list(0..(node_id_space-1)))
    nodes_first_group = Enum.slice(random_List, 0..(no_nodes_first_group-1))

    list_pid = for nodeID <- nodes_first_group do
      {_, pid} = PastryProtocol.startLink(nodeID, no_of_nodes)
      pid
    end 
    # Case: When First Join occurs
    for pid <- list_pid do
      GenServer.cast(pid, {:initiatePastry, nodes_first_group})
    end
    {:noreply, {no_of_nodes, random_List, no_of_reqs, no_joined, no_routed, no_hops}}
  end

  def handle_cast({:finish_route, hops}, state) do
    {no_of_nodes, random_List, no_of_reqs, no_joined, no_routed, no_hops} = state
    no_routed = no_routed + 1
    if hops < 0 do
      #IO.inspect "Negative Hops!"
    end
    no_hops = no_hops + hops
    if (no_routed >= no_of_nodes * no_of_reqs) do
      IO.puts "Total no. of routes: #{no_routed}"
      IO.puts "Total no. of hops: #{no_hops}"
      IO.puts "Average no. of hops/route: #{no_hops/no_routed}"
      Process.exit(self(), :shutdown)
    end
    {:noreply, {no_of_nodes, random_List, no_of_reqs, no_joined, no_routed, no_hops}}
  end

  def handle_cast(:start_route, state) do
    {_, random_List, no_of_reqs, _, _, _} = state
    for node <- random_List do
        GenServer.cast(String.to_atom("child"<>Integer.to_string(node)), {:start_routing, no_of_reqs})
    end
    {:noreply, state}
  end

  def handle_cast(:complete_join, state) do
    {no_of_nodes, random_List, no_of_reqs, no_joined, no_routed, no_hops} = state
    no_nodes_first_group = if (no_of_nodes <= 1024) do no_of_nodes else 1024 end
    no_joined = no_joined + 1
    if(no_joined >= no_nodes_first_group) do
      if(no_joined >= no_of_nodes) do
        GenServer.cast(:global.whereis_name(@name), :start_route)
      else
        GenServer.cast(:global.whereis_name(@name), :node_join)
      end
    end
    {:noreply, {no_of_nodes, random_List, no_of_reqs, no_joined, no_routed, no_hops}}
  end

  def handle_cast(:node_join, state) do
    {no_of_nodes, random_List, no_of_reqs, no_joined, no_routed, no_hops} = state
    start_id = Enum.at(random_List, Enum.random(0..(no_joined-1)))
    PastryProtocol.startLink(Enum.at(random_List, no_joined), no_of_nodes)
    GenServer.cast(String.to_atom("child"<>Integer.to_string(start_id)), {:route, "Join", start_id, Enum.at(random_List, no_joined), 0})
    {:noreply, {no_of_nodes, random_List, no_of_reqs, no_joined, no_routed, no_hops}}
  end

  def init([no_of_nodes, no_of_reqs, no_joined, no_routed, no_hops]) do
    {:ok, {no_of_nodes, [], no_of_reqs, no_joined, no_routed, no_hops}}
  end

  def start_link(no_of_nodes, no_of_reqs, no_joined, no_routed, no_hops) do
    GenServer.start_link(Project3, [no_of_nodes, no_of_reqs, no_joined, no_routed, no_hops])
  end

  def main(args) do
    [no_of_nodes, no_of_reqs] = args
    no_of_nodes = String.to_integer(no_of_nodes)
    no_of_reqs = String.to_integer(no_of_reqs)
    no_joined = 0
    no_routed = 0
    no_hops = 0
    {:ok, master_pid} = start_link(no_of_nodes, no_of_reqs, no_joined, no_routed, no_hops)
    :global.register_name(@name, master_pid)
    :global.sync()
    GenServer.cast(:global.whereis_name(@name), :begin_protocol)    
    :timer.sleep(:infinity)
  end
end