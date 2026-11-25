#!/bin/bash
usage() { echo "Usage runSubsetOfCypressTests.sh -c <current_run> -t <total_concurrent_runs> -f <test_name:test_name>" 1>&2; exit 1; }

additionalTestVars=""
while getopts ":c:t:d:f:" flag;
do
    case "${flag}" in
        c)
          currentRun=${OPTARG}
          ;;
        t)
          totalConcurrent=${OPTARG}
          ;;
        d)
          additionalTestVars=${OPTARG}
          ;;
        f)
          filterByTestsName=${OPTARG}
          ;;
        *)
          usage
          ;;
    esac
done
if [ -z "${currentRun}" ] || [ -z "${totalConcurrent}" ]; then
    usage
fi
if [ -z "${filterByTestsName}" ]; then
    filterByTestsName=' '
fi

echo "Running subset of service tests"
echo "Current Run: $currentRun";
echo "Additional Vars: $additionalTestVars";
echo "Total Concurrent: $totalConcurrent";
echo "Test names filters: [$filterByTestsName"]

cd ./cypress/e2e
IFS=$'\n'
# locate all of the tests files then "shuffle" in a repetitive order by sorting using md5sum
allTests=($(find . -type f -exec md5sum {} + | grep -i -E 'spec[s]?\.js' | grep -E $filterByTestsName | sort | cut -d " " -f 3))
#allTests=($(find . | grep -i -E 'spec[s]?\.js' | sort | cut -d " " -f 3))
unset IFS
cd ../../

totalNum=${#allTests[@]}
numPerRun=$((totalNum/totalConcurrent))
start=$(((currentRun-1)*numPerRun))
if  [ "$currentRun" -eq "$totalConcurrent" ]; then
    numPerRun=$totalNum
fi
testsInThisRun=${allTests[@]:$start:$numPerRun}
echo "There are [$totalNum] total tests. Run [$currentRun]: Start Number=[$start], running up to [$numPerRun] tests"

echo "Cypress tests:"
count=1
testsToRun=()
for testClass in ${testsInThisRun[@]}
do
  echo "$count: $testClass"
  count=$((count+1))
  testsToRun+=("cypress/e2e/${testClass}")
done
echo "------------------------------------------------"
testToRunStr=$(IFS=,; echo "${testsToRun[*]}")
echo "Will run [$testToRunStr]"

if npm run cy:run -- --spec "$testToRunStr"; then
    echo "Cypress run $currentRun of $totalConcurrent passed."
else
    status=$?
    echo "Cypress run $currentRun of $totalConcurrent failed with exit code $status. See the Cypress output above for details." >&2
    exit "$status"
fi
