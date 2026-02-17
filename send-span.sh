curl -i -X POST http://jaeger-server:4318/v1/traces \
     -H "Content-Type: application/json" \
     -d '{
 "resourceSpans": [
   {
     "resource": {
       "attributes": [
         { "key": "service.name", "value": { "stringValue": "bash-test-service" } }
       ]
     },
     "scopeSpans": [
       {
         "spans": [
           {
             "traceId": "4bf92f3577b34da6a3ce929d0e0e4736",
             "spanId": "0000000000000001",
             "name": "hello-world-span",
             "kind": 1,
             "startTimeUnixNano": "'$(date +%s%N)'",
             "endTimeUnixNano": "'$(($(date +%s%N) + 1000000))'",
             "status": { "code": 1 }
           }
         ]
       }
     ]
   }
 ]
}'
