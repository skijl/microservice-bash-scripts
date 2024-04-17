#████████████████████████████████████████████████████████████████████████████
#█░░░░░░░░░░░░░░█░░░░░░░░░░░░░░█░░░░░░░░░░░░░░█░░░░░░░░░░░░░░█░░░░░░░░░░░░░░█
#█░░▄▀▄▀▄▀▄▀▄▀░░█░░▄▀▄▀▄▀▄▀▄▀░░█░░▄▀▄▀▄▀▄▀▄▀░░█░░▄▀▄▀▄▀▄▀▄▀░░█░░▄▀▄▀▄▀▄▀▄▀░░█
#█░░░░░░▄▀░░░░░░█░░▄▀░░░░░░░░░░█░░▄▀░░░░░░░░░░█░░░░░░▄▀░░░░░░█░░▄▀░░░░░░░░░░█
#█████░░▄▀░░█████░░▄▀░░█████████░░▄▀░░█████████████░░▄▀░░█████░░▄▀░░█████████
#█████░░▄▀░░█████░░▄▀░░░░░░░░░░█░░▄▀░░░░░░░░░░█████░░▄▀░░█████░░▄▀░░░░░░░░░░█
#█████░░▄▀░░█████░░▄▀▄▀▄▀▄▀▄▀░░█░░▄▀▄▀▄▀▄▀▄▀░░█████░░▄▀░░█████░░▄▀▄▀▄▀▄▀▄▀░░█
#█████░░▄▀░░█████░░▄▀░░░░░░░░░░█░░░░░░░░░░▄▀░░█████░░▄▀░░█████░░░░░░░░░░▄▀░░█
#█████░░▄▀░░█████░░▄▀░░█████████████████░░▄▀░░█████░░▄▀░░█████████████░░▄▀░░█
#█████░░▄▀░░█████░░▄▀░░░░░░░░░░█░░░░░░░░░░▄▀░░█████░░▄▀░░█████░░░░░░░░░░▄▀░░█
#█████░░▄▀░░█████░░▄▀▄▀▄▀▄▀▄▀░░█░░▄▀▄▀▄▀▄▀▄▀░░█████░░▄▀░░█████░░▄▀▄▀▄▀▄▀▄▀░░█
#█████░░░░░░█████░░░░░░░░░░░░░░█░░░░░░░░░░░░░░█████░░░░░░█████░░░░░░░░░░░░░░█
#████████████████████████████████████████████████████████████████████████████
#!/bin/bash

# Check if the argument is provided
if [ ! -z "$1" ]; then
    cd "$1" || { echo "Error: Unable to navigate to $1"; exit 1; }
fi

# Check if src directory exists
if [ ! -d "src" ]; then
    echo "Error: 'src' directory not found in $1"
    exit 1
fi

# Find the directory containing the model directory
BASE_DIR=$(find src -type d -name "model" -printf "%h\n" | head -n 1)

# Check if model directory is found
if [ -z "$BASE_DIR" ]; then
    echo "Error: 'model' directory not found in 'src'"
    exit 1
fi

# Set the source directory for models
MODELS_DIR="$BASE_DIR/model"

# For imports
base_package_name=$(echo "$BASE_DIR" | sed 's|.*java/||; s|/|.|g')
TEST_BASE_DIR=$(echo "$BASE_DIR" | sed 's/main/test/')


# Function to create StaticObject classes-------------------------------------------------------------------------
create_static_object_classes() {
    local model_name="$1"
    local class_name="$1"
    if [ $# -eq 2 ]; then
        model_name="$2"  # Set model_name to second argument
    fi
    local lowercase_model_name=$(echo "${model_name:0:1}" | tr '[:upper:]' '[:lower:]')${model_name:1}
    local static_object_dir="$TEST_BASE_DIR/staticObject"
    mkdir -p "$static_object_dir"

    # Get the type of id
    id_line=$(grep -n "@Id" "$model_file" | head -n 1 | cut -d ":" -f 1)
    private_line=$(awk "NR > $id_line && /private/ {print NR; exit}" "$model_file")
    id_type=$(awk "NR==$private_line" "$model_file" | awk '{print $2}')
    id_name=$(awk "NR==$private_line" "$model_file" | awk '{print $3}')

    if [[ "${id_name: -1}" == ";" ]]; then
        id_name="${id_name::-1}"  # Remove the last character
    fi

    # Create Static<ModelName>.java
    static_file="$static_object_dir/Static${model_name}.java"
    echo "package ${base_package_name}.staticObject;" > "$static_file"
    echo "" >> "$static_file"
    echo "import ${base_package_name}.dto.request.${model_name}DtoRequest;" >> "$static_file"
    echo "import ${base_package_name}.dto.response.${model_name}DtoResponse;" >> "$static_file"
    echo "import ${base_package_name}.model.$class_name;" >> "$static_file"
    if grep -q "LocalDateTime" "$model_file"; then
        echo "import java.time.LocalDateTime;" >> "$static_file"
    fi
    if grep -q "BigDecimal" "$model_file"; then
        echo "import java.math.BigDecimal;" >> "$static_file"
    fi
    echo "" >> "$static_file"
    echo "public class Static${model_name} {" >> "$static_file"
    echo "" >> "$static_file"
    case "$id_type" in
            "String") echo "    public static final ${id_type} ID = \"${id_name}\";" >> "$static_file" ;;
            "Long") echo "    public static final ${id_type} ID = 1L;" >> "$static_file" ;;
            "Integer") echo "    public static final ${id_type} ID = 1;" >> "$static_file" ;;
            *) echo "    public static final ${id_type} ID = " ;;
        esac

    echo "" >> "$static_file"
    echo "    public static ${class_name} ${lowercase_model_name}1() {" >> "$static_file"
    echo "        ${class_name} model = new ${class_name}();" >> "$static_file"
    # Map the fields from model
    grep -E 'private .*;' "$model_file" | sed 's/private \([^ ]*\) \([^;]*\);/\1 \2/' | while read -r field; do
        field_type=$(echo "$field" | awk '{print $1}')
        field_name=$(echo "$field" | awk '{print $2}')
        case "$field_type" in
            "String") echo "        model.set${field_name^}(\"$field_name\");" >> "$static_file" ;;
            "Long") echo "        model.set${field_name^}(1L);" >> "$static_file" ;;
            "Integer") echo "        model.set${field_name^}(1);" >> "$static_file" ;;
            "BigDecimal") echo "        model.set${field_name^}(new BigDecimal(10));" >> "$static_file" ;;
            "LocalDateTime") echo "        model.set${field_name^}(LocalDateTime.MIN);" >> "$static_file" ;;
            *) echo "        model.set${field_name^}()" ;;
        esac
    done
    echo "        return model;" >> "$static_file"
    echo "    }" >> "$static_file"

     echo "" >> "$static_file"
    echo "    public static ${class_name} ${lowercase_model_name}1() {" >> "$static_file"
    echo "        ${class_name} model = new ${class_name}();" >> "$static_file"
    # Map the fields from model
    grep -E 'private .*;' "$model_file" | sed 's/private \([^ ]*\) \([^;]*\);/\1 \2/' | while read -r field; do
        field_type=$(echo "$field" | awk '{print $1}')
        field_name=$(echo "$field" | awk '{print $2}')
        case "$field_type" in
            "String") echo "        model.set${field_name^}(\"$field_name\");" >> "$static_file" ;;
            "Long") echo "        model.set${field_name^}(1L);" >> "$static_file" ;;
            "Integer") echo "        model.set${field_name^}(1);" >> "$static_file" ;;
            "BigDecimal") echo "        model.set${field_name^}(new BigDecimal(20));" >> "$static_file" ;;
            "LocalDateTime") echo "        model.set${field_name^}(LocalDateTime.MIN);" >> "$static_file" ;;
            *) echo "        model.set${field_name^}()" ;;
        esac
    done
    echo "        return model;" >> "$static_file"
    echo "    }" >> "$static_file"

    echo "" >> "$static_file"
    echo "    public static ${model_name}DtoRequest ${lowercase_model_name}DtoRequest1() {" >> "$static_file"
    echo "        ${model_name}DtoRequest dtoRequest = new ${model_name}DtoRequest();" >> "$static_file"
    # Map the fields from requestDto
    grep -E 'private .*;' "${BASE_DIR}/dto/request/${model_name}DtoRequest.java" | sed 's/private \([^ ]*\) \([^;]*\);/\1 \2/' | while read -r field; do
        field_type=$(echo "$field" | awk '{print $1}')
        field_name=$(echo "$field" | awk '{print $2}')
        case "$field_type" in
            "String") echo "        dtoRequest.set${field_name^}(\"${field_name}\");" >> "$static_file" ;;
            "Long") echo "        dtoRequest.set${field_name^}(1L);" >> "$static_file" ;;
            "Integer") echo "        dtoRequest.set${field_name^}(1);" >> "$static_file" ;;
            "BigDecimal") echo "        dtoRequest.set${field_name^}(new BigDecimal(10));" >> "$static_file" ;;
            "LocalDateTime") echo "        dtoRequest.set${field_name^}(LocalDateTime.MIN);" >> "$static_file" ;;
            *) ;;
        esac
    done
    echo "        return dtoRequest;" >> "$static_file"
    echo "    }" >> "$static_file"

    echo "" >> "$static_file"
    echo "    public static ${model_name}DtoResponse ${lowercase_model_name}DtoResponse1() {" >> "$static_file"
    echo "        ${model_name}DtoResponse dtoResponse = new ${model_name}DtoResponse();" >> "$static_file"
    # Map the fields from requestDto
    grep -E 'private .*;' "${BASE_DIR}/dto/response/${model_name}DtoResponse.java" | sed 's/private \([^ ]*\) \([^;]*\);/\1 \2/' | while read -r field; do
        field_type=$(echo "$field" | awk '{print $1}')
        field_name=$(echo "$field" | awk '{print $2}')
        case "$field_type" in
            "String") echo "        dtoResponse.set${field_name^}(\"${field_name}\");" >> "$static_file" ;;
            "Long") echo "        dtoResponse.set${field_name^}(1L);" >> "$static_file" ;;
            "Integer") echo "        dtoResponse.set${field_name^}(1);" >> "$static_file" ;;
            "BigDecimal") echo "        dtoResponse.set${field_name^}(new BigDecimal(10));" >> "$static_file" ;;
            "LocalDateTime") echo "        dtoResponse.set${field_name^}(LocalDateTime.MIN);" >> "$static_file" ;;
            *) ;;
        esac
    done
    echo "        return dtoResponse;" >> "$static_file"
    echo "    }" >> "$static_file"
    echo "" >> "$static_file"
    echo "" >> "$static_file"
    echo "}" >> "$static_file"
}

# Iterate over all Java files in the models directory
for model_file in "$MODELS_DIR"/*.java; do
    model_name=$(basename "$model_file" .java)
    if [[ $model_name == *Model ]]; then
        model_name_without_suffix="${model_name%Model}"
        create_static_object_classes "$model_name" "$model_name_without_suffix"
    else
        create_static_object_classes "$model_name"
    fi
done

echo "StaticObject classes generated successfully"

