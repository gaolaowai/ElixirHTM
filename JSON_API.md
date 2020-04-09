# JSON API

## About
The intent of this document is to propose or outline API calls that can be made in the json format to this HTM system. Rather than the current approach of passing raw parameters via URI, a better method would be to pass in json requests. Below is the currently proposed methods.

### Creating/Starting a new pool
JSON:
```JSON
{ "action": "create_pool",
  "params": 
       {
        "pool_id":"assigned/prefferid",
        "group_id": "id for a group of pools",
        "group_aware": true,
        "encoding_bit_length": 1000,
        "post_back_enable": true,
        "post_back_url": "https://someplace.to.post.outputs.to.com/SDRs",
        "minicolumn_params":
                       {
                       "minicolumn_in_pool": 10000,
                       "connectivity_to_input_space": 0.7,
                       "cells_per_minicolumn": 32,
                       "cleanup_frequency": 150
                       }
       }
}
```
* "group_id": Plan to support creating multiple pools that will accept/deal with different encodings
* "group_aware": Will this column be open to sharing/receiving winner information from other pools? This may be useful to wall off some pools into their own silo, while still being able to check state of the entire group when needed.
* "post_back_enable": Have an idea for SDRs from this pool to automatically post SDRs to a specified API endpoint.
* "post_back_url": host, ip, port, and endpoint which SDR data will be posted to if post_back is enabled.

### Getting Pool State
JSON:
```JSON
{ "action": "get_state",
  "params": 
       {
        "pool_id":"assigned/prefferid",
        "which_state": "TM/SP/ALL",
        "post_back_enable": true,
        "post_back_url": "https://ip:port/endpoint",
        "visual?": true
       }
}
```
* For "visual": (TODO!) send back a bitmap/svg of SDR that represents pool.
* "which_state": choose if pool sends back SDR of current winning columns, predicted columns, or concatenation of both.

### Getting state for a group of pools
JSON:
```JSON
{ "action": "get_state","which_state": "TM/SP/ALL",
  "params": 
       {
        "group_id":"assigned/prefferid",
        "which_state": "TM/SP/ALL",
        "post_back_enable": true,
        "post_back_url": "https://ip:port/endpoint",
        "visual?": true
       }
}
```
* For "visual": (TODO!) send back a bitmap/svg of SDR that represents pool.
* "which_state": choose if pool sends back SDR of current winning columns, predicted columns, or concatenation of both.

### Getting state for a group of pools
JSON:
```JSON
{ "action": "submit_encoding",
  "params": 
       {
        "pool_id":"assigned/prefferid",
        "encoding": "text of bits"
       }
}
```
Have some thoughts about how maybe this should accept binary data rather than ascii/unicode of 1's and 0's.
