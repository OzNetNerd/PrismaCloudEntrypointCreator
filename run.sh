#!/bin/bash

YELLOW='\033[0;33m'
WHITE='\033[0;37m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

IMAGE_NAME="example-redis-image"
TASK_DEFINITION_TEMPLATE_FILE_PATH="$(pwd)/src/fargate/task_definition_template.json"
OUTPUT_FILE_ENTRYPOINT="$(pwd)/task_definition_with_entrypoint.json"
OUTPUT_FILE_ENTRYPOINT_CMD="$(pwd)/task_definition_with_entrypoint_and_cmd.json"

TOTAL_LENGTH=150
SEPARATOR_1=$(printf '%*s' $TOTAL_LENGTH | tr ' ' '-')
SEPARATOR_2=$(printf '%*s' $TOTAL_LENGTH | tr ' ' '#')

#!/bin/bash

check_entrypoint() {
    echo -e "${YELLOW}Checking for ENTRYPOINT${NC}"

    local image_name="$1"
    local entrypoint=$(docker inspect --format='{{json .Config.Entrypoint}}' "$image_name" 2>/dev/null)

    if [[ $? -ne 0 ]]; then
        echo "${RED}Error: Failed to inspect $image_name. Ensure the image or container ID is correct."
        exit 1
    fi

    if [[ "$entrypoint" == "null" || -z "$entrypoint" ]]; then
        echo -e "${GREEN}ENTRYPOINT search result for $image_name: ${WHITE}NOT FOUND${NC}"
    else
        echo -e "${GREEN}ENTRYPOINT search result for $image_name: ${WHITE}FOUND - $entrypoint${NC}"
        echo -e "${GREEN}Exiting script${NC}"

        echo "$SEPARATOR_1"
        exit
    fi
}

extract_cmd() {
    local image_name="$1"
    local cmd_output

    cmd_output=$(docker inspect --format '{{json .Config.Cmd}}' "$image_name")

    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to extract CMD.${NC}" >&2
        exit 1
    fi

    echo "$cmd_output"
}

create_entrypoint_task_definition() {
    local original_cmd="$1"
    local json_content

    echo -e "${YELLOW}Creating new ENTRYPOINT Task Definition file: ${WHITE}$OUTPUT_FILE_ENTRYPOINT${NC}"
    echo -e "${GREEN}Reading Task Definition template file: ${WHITE}$TASK_DEFINITION_TEMPLATE_FILE_PATH${NC}"
    json_content=$(<"$TASK_DEFINITION_TEMPLATE_FILE_PATH")

    json_content=$(echo "$json_content" | jq 'del(.containerDefinitions[].command)')
    echo -e "${GREEN}Removed: ${WHITE}Empty CMD array from template${NC}"

    json_content=$(echo "$json_content" | jq --argjson cmd "$original_cmd" '.containerDefinitions[].entryPoint = $cmd')
    echo -e "${GREEN}Set ENTRYPOINT to: ${WHITE}$original_cmd${NC}"

    echo -e "${GREEN}Output ENTRYPOINT Task Definition to a new file: ${WHITE}$OUTPUT_FILE_ENTRYPOINT${NC}"
    echo "$json_content" >"$OUTPUT_FILE_ENTRYPOINT"
    echo -e "${GREEN}Done${NC}"
}

create_entrypoint_and_cmd_task_definition() {
    local original_cmd="$1"
    local json_content

    echo -e "${YELLOW}Creating new ENTRYPOINT & CMD Task Definition file: ${WHITE}$OUTPUT_FILE_ENTRYPOINT${NC}"
    echo -e "${GREEN}Reading Task Definition template file: ${WHITE}$TASK_DEFINITION_TEMPLATE_FILE_PATH${NC}"
    json_content=$(<"$TASK_DEFINITION_TEMPLATE_FILE_PATH")

    echo -e "${GREEN}Splitting command into ENTRYPOINT and CMD: ${WHITE}$original_cmd${NC}"
    entrypoint=$(echo "$original_cmd" | jq -r '.[0]')
    cmd=$(echo "$original_cmd" | jq -c '.[1:]')

    echo -e "${GREEN}Extracted ENTRYPOINT: ${WHITE}$entrypoint${NC}"
    echo -e "${GREEN}Extracted CMD: ${WHITE}$cmd${NC}"

    json_content=$(echo "$json_content" | jq --arg entrypoint "$entrypoint" --argjson cmd "$cmd" '
    .containerDefinitions[].entryPoint = [$entrypoint] |
    .containerDefinitions[].command = $cmd
')

    echo -e "${GREEN}Update template and output ENTRYPOINT & CMD Task Definition to a new file: ${WHITE}$OUTPUT_FILE_ENTRYPOINT${NC}"
    echo "$json_content" >"$OUTPUT_FILE_ENTRYPOINT_CMD"
    echo -e "${GREEN}Done${NC}"
}

if [ -z "$1" ]; then
    echo -e "${RED}Error: No image name provided${NC}"
    echo -e "${YELLOW}Usage: $0 <image_name>${NC}"
    exit 1
fi

image_name="$1"

echo "$SEPARATOR_1"
check_entrypoint $image_name
echo "$SEPARATOR_1"
echo -e "${YELLOW}Extracting CMD command from image: ${WHITE}$image_name${NC}"

ORIGINAL_CMD=$(extract_cmd "$image_name")
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Extracted CMD command: ${WHITE}$ORIGINAL_CMD${NC}"
    echo -e "${GREEN}Done${NC}"
    echo "$SEPARATOR_1"
    create_entrypoint_task_definition "$ORIGINAL_CMD"
    echo "$SEPARATOR_1"
    create_entrypoint_and_cmd_task_definition "$ORIGINAL_CMD"
else
    echo -e "${RED}Eror: Failed to extract CMD. Exiting.${NC}"
    exit 1
fi

echo
echo "$SEPARATOR_2"
echo -e "${YELLOW}EXECUTION SUCCESSFUL${NC}"
echo "$SEPARATOR_2"
echo -e "${GREEN}Successfully Extracted CMD command ${WHITE}$ORIGINAL_CMD ${GREEN}and created two new Task Definition files:${NC}"
echo -e "${GREEN}ENTRYPOINT Task Definition: ${WHITE}$OUTPUT_FILE_ENTRYPOINT${NC}"
echo -e "${GREEN}ENTRYPOINT & CMD Task Definition: ${WHITE}$OUTPUT_FILE_ENTRYPOINT_CMD${NC}"
echo "$SEPARATOR_2"
