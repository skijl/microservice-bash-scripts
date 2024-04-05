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
# Set the target directory for DTO mappers
MAPPER_DIR="$BASE_DIR/dto/dtoMapper"
# For imports
base_package_name=$(echo "$BASE_DIR" | sed 's|.*java/||; s|/|.|g')

# Create target directory if it doesn't exist
mkdir -p "$MAPPER_DIR"

# Function to generate DTO mappers
generate_dto_mapper() {
    local model_file="$1"
    local model_name=$(basename "$model_file" .java)
    local lowercase_model_name=$(echo "$model_name" | tr '[:upper:]' '[:lower:]')
    local mapper_dir="$MAPPER_DIR"
    mkdir -p "$mapper_dir"
    create_mapper_file="$mapper_dir/${model_name}DtoMapper.java"

    # Extract package name from the DTO directory structure
    package_name=$(dirname "${create_mapper_file}" | sed 's|.*java/||; s|/|.|g')
    
    # Add imports for model and DTO classes
    echo "package $package_name;" > "$create_mapper_file"
    echo "" >> "$create_mapper_file"
    echo "import $base_package_name.model.$model_name;" >> "$create_mapper_file"
    echo "import ${base_package_name}.dto.request.${model_name}DtoRequest;" >> "$create_mapper_file"
    echo "import ${base_package_name}.dto.response.${model_name}DtoResponse;" >> "$create_mapper_file"
    echo "" >> "$create_mapper_file"

    echo "public class ${model_name}DtoMapper {" >> "$create_mapper_file"
    echo "" >> "$create_mapper_file"

    # Generate DTO Mapper class
    # Generate toModel method
    echo "    public static $model_name toModel(${model_name}DtoRequest request) {" >> "$create_mapper_file"
    echo "        $model_name model = new $model_name();" >> "$create_mapper_file"
    echo "" >> "$create_mapper_file"
    # Iterate over fields in the model
    grep -E 'private .*;' "$model_file" | sed 's/private \([^ ]*\) \([^;]*\);/\1 \2/' | while read -r field; do
        field_name=$(echo "$field" | awk '{print $2}')
        # Check if field exists in CreateRequest and map it
        if grep -q "private .* $field_name;" "$BASE_DIR/dto/request/${model_name}DtoRequest.java"; then
            echo "        model.set${field_name^}(request.get${field_name^}());" >> "$create_mapper_file"
        fi
    done
    echo "" >> "$create_mapper_file"
    echo "        return model;" >> "$create_mapper_file"
    echo "    }" >> "$create_mapper_file"
    echo "" >> "$create_mapper_file"

    # Generate toResponse method
    echo "    public static $model_name toResponse(${model_name} model) {" >> "$create_mapper_file"
    echo "        ${model_name}DtoResponse response = new ${model_name}DtoResponse();" >> "$create_mapper_file"
    echo "" >> "$create_mapper_file"
    # Iterate over fields in the model
    grep -E 'private .*;' "$model_file" | sed 's/private \([^ ]*\) \([^;]*\);/\1 \2/' | while read -r field; do
        field_name=$(echo "$field" | awk '{print $2}')
        # Check if field exists in CreateResponse and map it
        if grep -q "private .* $field_name;" "$BASE_DIR/dto/response/${model_name}DtoResponse.java"; then
            echo "        model.set${field_name^}(response.get${field_name^}());" >> "$create_mapper_file"
        fi
    done
    echo "" >> "$create_mapper_file"
    echo "        return model;" >> "$create_mapper_file"
    echo "    }" >> "$create_mapper_file"
    echo "}" >> "$create_mapper_file"
}

# Iterate over all Java files in the models directory
for model_file in "$MODELS_DIR"/*.java; do
    generate_dto_mapper "$model_file"
done

echo "DTO Mappers generated successfully"
# Set the target directory for repositories
REPOSITORY_DIR="$BASE_DIR/repository"
mkdir -p "$REPOSITORY_DIR"

# Function to generate repository interface
generate_repository() {
    local model_file="$1"
    local model_name=$(basename "$model_file" .java)
    local repository_file="$REPOSITORY_DIR/${model_name}Repository.java"
    package_name=$(dirname "${repository_file}" | sed 's|.*java/||; s|/|.|g')
    
    # Add imports for model and DTO classes
    echo "package $package_name;" > "$repository_file"
    echo "" >> "$repository_file"
    echo "import $base_package_name.model.$model_name;" >> "$repository_file"
    
    # Get the type of id
    id_line=$(grep -n "@Id" "$model_file" | head -n 1 | cut -d ":" -f 1)
    private_line=$(awk "NR > $id_line && /private/ {print NR; exit}" "$model_file")
    id_type=$(awk "NR==$private_line" "$model_file" | awk '{print $2}')

    # Check if the model class has the @Entity annotation
    if grep -q "@Entity" "$model_file"; then
        repository_extension="JpaRepository<${model_name}, ${id_type}>"
        echo "import org.springframework.data.jpa.repository.JpaRepository;" >> "$repository_file"
    # Check if the model class has the @Document annotation
    elif grep -q "@Document" "$model_file"; then
        repository_extension="MongoRepository<${model_name}, ${id_type}>"
        echo "import org.springframework.data.mongodb.repository.MongoRepository;" >> "$repository_file"
    else
        echo "Error: Model class '$model_name' does not have @Entity or @Document annotation"
        exit 1
    fi

    # Generate repository interface
    echo "" >> "$repository_file"
    echo "public interface ${model_name}Repository extends $repository_extension {" >> "$repository_file"
    echo "" >> "$repository_file"
    echo "}" >> "$repository_file"
}



# Iterate over all Java files in the models directory
for model_file in "$MODELS_DIR"/*.java; do
    generate_repository "$model_file"
done

echo "Repository interfaces generated successfully."