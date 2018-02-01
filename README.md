# Project3


Team Members - Aisharjya Sarkar (UFID - 4495-5999) and Debarshi Mitra (UFID - 3381-3136)

What is Working - 

Using actor model, we implemented the Pastry protocol for network join and routing functionalities. The number of nodes and number of requests 
are taken as input. Each node sends a request to another node randomly. When each node performs that many requests, the program terminates. Next 
we calculate the average number of hops. Initially, we divide the number of nodes given as input into two groups if it exceeds 1024. Therefore, 
the initial network structure contains a max of 1024 nodes. The remaining nodes join the existing network by the network join functionality. 

With 10 requests, the algorithm is ran over 100, 500, 1000, 2000, 3000, 4000, 5000 and 10,000 nodes. The average number of hops achieved is as given below: 

Nodes			Average number of hops
--------------------------------------
100			3.197
500			4.1574
1000			4.5029
2000			5.0815
3000			5.4263
4000			5.68675
5000			5.91154
10000			6.54498


What is the largest network you managed to deal with - 

The largest network that was run in the system was with 10,000 nodes and number of Requests made was 10.

./project3 10000 10
Total no. of routes: 100000
Total no. of hops: 654498
Average no. of hops/route: 6.54498
** (EXIT from #PID<0.76.0>) shutdown

-------------------------------------------------------------------------------------------------


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `project3` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:project3, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/project3](https://hexdocs.pm/project3).

