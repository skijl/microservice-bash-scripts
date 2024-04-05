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
# Function to generate DTOs
generate_reqest_dto() {
    TARGET_DIR="$BASE_DIR/dto/request"
    local model_file="$1"
    local request_type="DtoRequest"
    local model_name=$(basename "$model_file" .java)
    local lowercase_model_name=$(echo "$model_name" | tr '[:upper:]' '[:lower:]')
    local dto_dir="$TARGET_DIR"
    mkdir -p "$dto_dir"
    create_request_file="$dto_dir/${model_name}${request_type}.java"

    # Extract package name from the DTO directory structure
    package_name=$(dirname "${create_request_file}" | sed 's|.*java/||; s|/|.|g')
    echo  "Created "${create_request_file}

    # Add imports
    echo "package $package_name;" > "$create_request_file"
    echo "" >> "$create_request_file"
    echo "import jakarta.validation.constraints.NotBlank;" >> "$create_request_file"
    echo "import jakarta.validation.constraints.NotNull;" >> "$create_request_file"
    echo "import jakarta.validation.constraints.Positive;" >> "$create_request_file"
    echo "import lombok.Data;" >> "$create_request_file"
    echo "import lombok.AllArgsConstructor;" >> "$create_request_file"
    echo "import lombok.NoArgsConstructor;" >> "$create_request_file"
    echo "" >> "$create_request_file"

    if grep -q "BigDecimal" "$model_file"; then
        echo "import java.math.BigDecimal;" >> "$create_request_file"
    fi
    echo "" >> "$create_request_file"

    # Generate CreateRequest class
    echo "@AllArgsConstructor" >> "$create_request_file"
    echo "@NoArgsConstructor" >> "$create_request_file"
    echo "@Data" >> "$create_request_file"
    echo "public class $(basename "$create_request_file" .java) {" >> "$create_request_file"

    # Extract fields from the original model class, excluding id field and LocalDateTime type
    fields=$(grep -E 'private .*;' "$model_file" | sed 's/private \([^ ]*\) \([^;]*\);/\1 \2/' | grep -v "id" | grep -v "LocalDateTime")

    # Iterate over fields
    while IFS= read -r field; do
        # Extract field type and name
        field_type=$(echo "$field" | awk '{print $1}')
        field_name=$(echo "$field" | awk '{print toupper(substr($2,1,1)) substr($2,2)}')

        # Check field type and add validation annotations accordingly
        case "$field_type" in
            String)
                echo "    @NotNull(message = \"$field_name cannot be null\")" >> "$create_request_file"
                echo "    @NotBlank(message = \"$field_name cannot be blank\")" >> "$create_request_file"
                ;;
            Long|Integer|BigDecimal)
                echo "    @Positive(message = \"$field_name must be a positive number\")" >> "$create_request_file"
                echo "    @NotNull(message = \"$field_name cannot be null\")" >> "$create_request_file"
                ;;
            *)
                # Leave other types without annotations
                ;;
        esac

        # Add field declaration to the class without indentation and with semicolon
        trimmed_field="${field:4}"  # Remove the first four characters
        echo "    private ${trimmed_field};" >> "$create_request_file"
        echo "" >> "$create_request_file"
    done <<< "$fields"

    # Close CreateRequest class
    echo "}" >> "$create_request_file"
}

generate_response_dto() {
    TARGET_DIR="$BASE_DIR/dto/response"
    local model_file="$1"
    local response_type="DtoResponse"
    local model_name=$(basename "$model_file" .java)
    local lowercase_model_name=$(echo "$model_name" | tr '[:upper:]' '[:lower:]')
    local dto_dir="$TARGET_DIR"
    mkdir -p "$dto_dir"
    create_response_file="$dto_dir/${model_name}${response_type}.java"

    # Extract package name from the DTO directory structure
    package_name=$(dirname "${create_response_file}" | sed 's|.*java/||; s|/|.|g')
    echo  "Created "${create_response_file}

    # Add imports
    echo "package $package_name;" > "$create_response_file"
    echo "" >> "$create_response_file"

    echo "import lombok.Data;" >> "$create_response_file" 
    echo "import lombok.AllArgsConstructor;" >> "$create_response_file"
    echo "import lombok.NoArgsConstructor;" >> "$create_response_file"
    echo "" >> "$create_response_file"

    if grep -q "LocalDateTime" "$model_file"; then
        echo "import java.time.LocalDateTime;" >> "$create_response_file"
    fi
    if grep -q "BigDecimal" "$model_file"; then
        echo "import java.math.BigDecimal;" >> "$create_response_file"
    fi
    echo "" >> "$create_response_file"

    # Generate CreateRequest class
    echo "@AllArgsConstructor" >> "$create_response_file"
    echo "@NoArgsConstructor" >> "$create_response_file"
    echo "@Data" >> "$create_response_file"
    echo "public class $(basename "$create_response_file" .java) {" >> "$create_response_file"

    # Extract fields from the original model class, excluding id field and LocalDateTime type
    fields=$(grep -E 'private .*;' "$model_file" | sed 's/private \([^ ]*\) \([^;]*\);/\1 \2/')

    # Iterate over fields
    while IFS= read -r field; do
        # Extract field type and name
        field_type=$(echo "$field" | awk '{print $1}')
        field_name=$(echo "$field" | awk '{print toupper(substr($2,1,1)) substr($2,2)}')

        # Add field declaration to the class without indentation and with semicolon
        trimmed_field="${field:4}"  # Remove the first four characters
        echo "    private ${trimmed_field};" >> "$create_response_file"
        echo "" >> "$create_response_file"
    done <<< "$fields"

    # Close CreateRequest class
    echo "}" >> "$create_response_file"
}
# Iterate over all Java files in the models directory
for model_file in "$MODELS_DIR"/*.java; do
    generate_reqest_dto "$model_file" "$request_type"
done



for model_file in "$MODELS_DIR"/*.java; do
    generate_response_dto "$model_file" "$response_type"
done
echo "Now adjust your DTOs before running the next script"