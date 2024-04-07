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

# Function to generate DTO Requests---------------------------------------------------------------------------------------------------------
generate_reqest_dto() {
    TARGET_DIR="$BASE_DIR/dto/request"
    local model_file="$1"
    local request_type="DtoRequest"
    local model_name=$(basename "$model_file" .java)
    if [[ $model_name == *Model ]]; then
        model_name="${model_name%Model}"
    fi

    local lowercase_model_name=$(echo "$model_name" | tr '[:upper:]' '[:lower:]')
    local dto_dir="$TARGET_DIR"
    mkdir -p "$dto_dir"
    create_request_file="$dto_dir/${model_name}${request_type}.java"

    # Extract package name from the DTO directory structure
    package_name=$(dirname "${create_request_file}" | sed 's|.*java/||; s|/|.|g')

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
    if grep -q " Date " "$model_file"; then
        echo "import java.util.Date;" >> "$create_request_file"
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

# Function to generate DTO Responses---------------------------------------------------------------------------------------------------------
generate_response_dto() {
    TARGET_DIR="$BASE_DIR/dto/response"
    local model_file="$1"
    local response_type="DtoResponse"
    local model_name=$(basename "$model_file" .java)
    if [[ $model_name == *Model ]]; then
        model_name="${model_name%Model}"
    fi
    local lowercase_model_name=$(echo "$model_name" | tr '[:upper:]' '[:lower:]')
    local dto_dir="$TARGET_DIR"
    mkdir -p "$dto_dir"
    create_response_file="$dto_dir/${model_name}${response_type}.java"

    # Extract package name from the DTO directory structure
    package_name=$(dirname "${create_response_file}" | sed 's|.*java/||; s|/|.|g')

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
echo "DTO Requests generated successfully"


for model_file in "$MODELS_DIR"/*.java; do
    generate_response_dto "$model_file" "$response_type"
done
echo "DTO Responses generated successfully"

echo ""
echo "Now adjust your DTOs before running the next script"
read -p "Do you want to continue? (Y/n): " choice

# Check if the choice is 'y' or 'Y', then continue
if ! [[ "$choice" =~ ^[Yy]$ ]]; then
    exit 1
fi

# Function to generate DTO mappers---------------------------------------------------------------------------------------------------------
generate_dto_mapper() {
    local model_name="$1"
    local class_name="$1"
    if [ $# -eq 2 ]; then
        model_name="$2"  # Set model_name to second argument
    fi
    # Set the target directory for DTO mappers
    local lowercase_model_name=$(echo "$model_name" | tr '[:upper:]' '[:lower:]')
    local mapper_dir="$BASE_DIR/dto/dtoMapper"
    mkdir -p "$mapper_dir"
    create_mapper_file="$mapper_dir/${model_name}DtoMapper.java"

    # Extract package name from the DTO directory structure
    package_name=$(dirname "${create_mapper_file}" | sed 's|.*java/||; s|/|.|g')
    
    # Add imports for model and DTO classes
    echo "package $package_name;" > "$create_mapper_file"
    echo "" >> "$create_mapper_file"
    echo "import $base_package_name.model.$class_name;" >> "$create_mapper_file"
    echo "import ${base_package_name}.dto.request.${model_name}DtoRequest;" >> "$create_mapper_file"
    echo "import ${base_package_name}.dto.response.${model_name}DtoResponse;" >> "$create_mapper_file"
    echo "" >> "$create_mapper_file"

    echo "public class ${model_name}DtoMapper {" >> "$create_mapper_file"
    echo "" >> "$create_mapper_file"

    # Generate DTO Mapper class
    # Generate toModel method
    echo "    public static $class_name toModel(${model_name}DtoRequest request) {" >> "$create_mapper_file"
    echo "        $class_name model = new $class_name();" >> "$create_mapper_file"
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
    echo "    public static ${model_name}DtoResponse toResponse(${class_name} model) {" >> "$create_mapper_file"
    echo "        ${model_name}DtoResponse response = new ${model_name}DtoResponse();" >> "$create_mapper_file"
    echo "" >> "$create_mapper_file"
    # Iterate over fields in the model
    grep -E 'private .*;' "$model_file" | sed 's/private \([^ ]*\) \([^;]*\);/\1 \2/' | while read -r field; do
        field_name=$(echo "$field" | awk '{print $2}')
        # Check if field exists in CreateResponse and map it
        if grep -q "private .* $field_name;" "$BASE_DIR/dto/response/${model_name}DtoResponse.java"; then
            echo "        response.set${field_name^}(model.get${field_name^}());" >> "$create_mapper_file"
        fi
    done
    echo "" >> "$create_mapper_file"
    echo "        return response;" >> "$create_mapper_file"
    echo "    }" >> "$create_mapper_file"
    echo "}" >> "$create_mapper_file"
}

for model_file in "$MODELS_DIR"/*.java; do
    model_name=$(basename "$model_file" .java)
    if [[ $model_name == *Model ]]; then
        model_name_without_suffix="${model_name%Model}"
        generate_dto_mapper "$model_name" "$model_name_without_suffix"
    else
        generate_dto_mapper "$model_name"
    fi
done

echo "DTO Mappers generated successfully"

# Function to generate repository interface---------------------------------------------------------------------------------------------------------
REPOSITORY_DIR="$BASE_DIR/repository"
mkdir -p "$REPOSITORY_DIR"

generate_repository() {
    local model_name="$1"
    local class_name="$1"
    if [ $# -eq 2 ]; then
        model_name="$2"  # Set model_name to second argument
    fi

    local repository_file="$REPOSITORY_DIR/${model_name}Repository.java"
    package_name=$(dirname "${repository_file}" | sed 's|.*java/||; s|/|.|g')

    # Add imports for model and DTO classes
    echo "package $package_name;" > "$repository_file"
    echo "" >> "$repository_file"
    echo "import $base_package_name.model.$class_name;" >> "$repository_file"

    # Get the type of id
    id_line=$(grep -n "@Id" "$model_file" | head -n 1 | cut -d ":" -f 1)
    private_line=$(awk "NR > $id_line && /private/ {print NR; exit}" "$model_file")
    id_type=$(awk "NR==$private_line" "$model_file" | awk '{print $2}')

    # Check if the model class has the @Entity annotation
    if grep -q "@Entity" "$model_file"; then
        repository_extension="JpaRepository<${class_name}, ${id_type}>"
        echo "import org.springframework.data.jpa.repository.JpaRepository;" >> "$repository_file"
    # Check if the model class has the @Document annotation
    elif grep -q "@Document" "$model_file"; then
        repository_extension="MongoRepository<${class_name}, ${id_type}>"
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
    model_name=$(basename "$model_file" .java)
    if [[ $model_name == *Model ]]; then
        model_name_without_suffix="${model_name%Model}"
        generate_repository "$model_name" "$model_name_without_suffix"
    else
        generate_repository "$model_name"
    fi
done

echo "Repository interfaces generated successfully."

# Function to generate service interface---------------------------------------------------------------------------------------------------------
generate_service_interface() {
    local model_name="$1"
    local class_name="$1"
    if [ $# -eq 2 ]; then
        model_name="$2"  # Set model_name to second argument
    fi

    local lowercase_model_name="${model_name,}"
    local service_file="$BASE_DIR/service/${model_name}Service.java"
    package_name=$(dirname "${service_file}" | sed 's|.*java/||; s|/|.|g')

    # Add package and imports for model class
    echo "package $package_name;" > "$service_file"
    echo "" >> "$service_file"
    echo "import $base_package_name.model.$class_name;" >> "$service_file"
    echo "" >> "$service_file"

    # Get the type of id
    id_line=$(grep -n "@Id" "$model_file" | head -n 1 | cut -d ":" -f 1)
    private_line=$(awk "NR > $id_line && /private/ {print NR; exit}" "$model_file")
    id_type=$(awk "NR==$private_line" "$model_file" | awk '{print $2}')

    # Generate service interface
    echo "public interface ${model_name}Service {" >> "$service_file"
    echo "    public $class_name create($class_name $lowercase_model_name);" >> "$service_file"
    echo "    public $class_name getById($id_type id);" >> "$service_file"
    echo "    public $class_name update($id_type id, $class_name $lowercase_model_name);" >> "$service_file"
    echo "    public Boolean deleteById($id_type id);" >> "$service_file"
    echo "}" >> "$service_file"
}

mkdir -p "$BASE_DIR/service"

# Iterate over all Java files in the models directory
for model_file in "$MODELS_DIR"/*.java; do
    model_name=$(basename "$model_file" .java)
    if [[ $model_name == *Model ]]; then
        model_name_without_suffix="${model_name%Model}"
        generate_service_interface "$model_name" "$model_name_without_suffix"
    else
        generate_service_interface "$model_name"
    fi
done

echo "Service interfaces generated successfully."
# Function to generate exception package and exceptions---------------------------------------------------------------------------------------------------------
generate_exceptions_package(){
    local EXCEPTION_DIR="$BASE_DIR/exception"
    mkdir -p "$EXCEPTION_DIR"
    package_name=$(realpath "${EXCEPTION_DIR}" | sed 's|.*java/||; s|/|.|g')
    
    # Generate ExceptionPayload class
    echo "package $package_name;" > "$EXCEPTION_DIR/ExceptionPayload.java"
    echo "" >> "$EXCEPTION_DIR/ExceptionPayload.java"
    echo 'import lombok.AllArgsConstructor;' >> "$EXCEPTION_DIR/ExceptionPayload.java"
    echo 'import lombok.Data;' >> "$EXCEPTION_DIR/ExceptionPayload.java"
    echo 'import lombok.NoArgsConstructor;' >> "$EXCEPTION_DIR/ExceptionPayload.java"
    echo '' >> "$EXCEPTION_DIR/ExceptionPayload.java"
    echo '@AllArgsConstructor' >> "$EXCEPTION_DIR/ExceptionPayload.java"
    echo '@NoArgsConstructor' >> "$EXCEPTION_DIR/ExceptionPayload.java"
    echo '@Data' >> "$EXCEPTION_DIR/ExceptionPayload.java"
    echo 'public class ExceptionPayload {' >> "$EXCEPTION_DIR/ExceptionPayload.java"
    echo '    private Object errorMessage;' >> "$EXCEPTION_DIR/ExceptionPayload.java"
    echo '    private String documentationUri;' >> "$EXCEPTION_DIR/ExceptionPayload.java"
    echo '}' >> "$EXCEPTION_DIR/ExceptionPayload.java"

    # Generate EntityNotFoundException class
    echo "package $package_name;" > "$EXCEPTION_DIR/EntityNotFoundException.java"
    echo "" >> "$EXCEPTION_DIR/EntityNotFoundException.java"
    echo 'public class EntityNotFoundException extends RuntimeException{' >> "$EXCEPTION_DIR/EntityNotFoundException.java"
    echo '    public EntityNotFoundException(String message) {' >> "$EXCEPTION_DIR/EntityNotFoundException.java"
    echo '        super(message);' >> "$EXCEPTION_DIR/EntityNotFoundException.java"
    echo '    }' >> "$EXCEPTION_DIR/EntityNotFoundException.java"
    echo '}' >> "$EXCEPTION_DIR/EntityNotFoundException.java"

    # Generate GlobalExceptionHandler class
    echo "package $package_name;" > "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo "" >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo 'import org.springframework.beans.factory.annotation.Value;' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo 'import org.springframework.http.HttpStatus;' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo 'import org.springframework.http.ResponseEntity;' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo 'import org.springframework.validation.FieldError;' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo 'import org.springframework.web.bind.MethodArgumentNotValidException;' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo 'import org.springframework.web.bind.annotation.ExceptionHandler;' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo 'import org.springframework.web.bind.annotation.RestControllerAdvice;' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo 'import java.util.HashMap;' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo 'import java.util.Map;' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '@RestControllerAdvice' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo 'public class GlobalExceptionHandler {' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '    private final String DOCUMENTATION_URI;' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '    public GlobalExceptionHandler(@Value("${swagger.documentation.uri}") String DOCUMENTATION_URI) {' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '        this.DOCUMENTATION_URI = DOCUMENTATION_URI;' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '    }' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '    @ExceptionHandler(MethodArgumentNotValidException.class)' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '    public ResponseEntity<Object> handleConstraintViolationException(MethodArgumentNotValidException e) {' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '        Map<String, String> errors = new HashMap<>();' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '        e.getBindingResult().getAllErrors().forEach(error -> {' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '            String fieldName = ((FieldError) error).getField();' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '            String errorMessage = error.getDefaultMessage();' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '            errors.put(fieldName, errorMessage);' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '        });' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '        return new ResponseEntity<>(new ExceptionPayload(errors, DOCUMENTATION_URI), HttpStatus.BAD_REQUEST);' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '    }' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '    @ExceptionHandler(EntityNotFoundException.class)' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '    public ResponseEntity<Object> handlerElasticsearchNotFoundExceptionEntityNotFoundException(EntityNotFoundException e){' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '        return new ResponseEntity<>(new ExceptionPayload(e.getMessage(), DOCUMENTATION_URI), HttpStatus.NOT_FOUND);' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '    }' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
    echo '}' >> "$EXCEPTION_DIR/GlobalExceptionHandler.java"
}
generate_exceptions_package
echo "Exception implementations generated successfully."
# Function to generate service implementation class---------------------------------------------------------------------------------------------------------
generate_service_impl_class() {
    local SERVICE_IMPL_DIR="$BASE_DIR/service/impl"
    local model_name="$1"
    local class_name="$1"
    if [ $# -eq 2 ]; then
        model_name="$2"  # Set model_name to second argument
    fi
    
    local lowercase_model_name="${model_name,}"
    local service_impl_file="$SERVICE_IMPL_DIR/${model_name}ServiceImpl.java"
    package_name=$(dirname "${service_impl_file}" | sed 's|.*java/||; s|/|.|g')

    # Get the type of id
    id_line=$(grep -n "@Id" "$model_file" | head -n 1 | cut -d ":" -f 1)
    private_line=$(awk "NR > $id_line && /private/ {print NR; exit}" "$model_file")
    id_type=$(awk "NR==$private_line" "$model_file" | awk '{print $2}')

    # Add imports for model class and service interface
    echo "package $package_name;" > "$service_impl_file"
    echo "" >> "$service_impl_file"
    echo "import $base_package_name.model.$class_name;" >> "$service_impl_file"
    echo "import $base_package_name.service.${model_name}Service;" >> "$service_impl_file"
    echo "import $base_package_name.exception.EntityNotFoundException;" >> "$service_impl_file"
    echo "import $base_package_name.repository.${model_name}Repository;" >> "$service_impl_file"
    echo "import lombok.extern.slf4j.Slf4j;" >> "$service_impl_file"
    echo "import org.springframework.stereotype.Service;" >> "$service_impl_file"
    echo "" >> "$service_impl_file"

    # Generate service implementation class
    echo "@Slf4j" >> "$service_impl_file"
    echo "@Service" >> "$service_impl_file"
    echo "public class ${model_name}ServiceImpl implements ${model_name}Service {" >> "$service_impl_file"
    echo "    private final ${model_name}Repository ${lowercase_model_name}Repository;" >> "$service_impl_file"
    echo "" >> "$service_impl_file"
    echo "    public ${model_name}ServiceImpl(${model_name}Repository ${lowercase_model_name}Repository) {" >> "$service_impl_file"
    echo "        this.${lowercase_model_name}Repository = ${lowercase_model_name}Repository;" >> "$service_impl_file"
    echo "    }" >> "$service_impl_file"
    echo "" >> "$service_impl_file"

    echo "    @Override" >> "$service_impl_file"
    echo "    public $class_name create($class_name $lowercase_model_name) {" >> "$service_impl_file"
    echo "        log.info(\"$class_name create: {}\", $lowercase_model_name);" >> "$service_impl_file"
    echo "        return ${lowercase_model_name}Repository.save($lowercase_model_name);" >> "$service_impl_file"
    echo "    }" >> "$service_impl_file"
    echo "" >> "$service_impl_file"

    echo "    @Override" >> "$service_impl_file"
    echo "    public $class_name getById($id_type id) {" >> "$service_impl_file"
    echo "        log.info(\"$class_name get by id: {}\", id);" >> "$service_impl_file"
    echo "        return ${lowercase_model_name}Repository.findById(id).orElseThrow(()->new EntityNotFoundException(\"NotificationChannel with id\" + id + \"does not exist\"));" >> "$service_impl_file"
    echo "    }" >> "$service_impl_file"
    echo "" >> "$service_impl_file"

    echo "    @Override" >> "$service_impl_file"
    echo "    public $class_name update($id_type id, $class_name $lowercase_model_name) {" >> "$service_impl_file"
    echo "        $class_name updated$model_name = getById(id);" >> "$service_impl_file"
    # Map the fields from model to updatedModel
    grep -E 'private .*;' "$model_file" | sed 's/private \([^ ]*\) \([^;]*\);/\1 \2/' | while read -r field; do
        field_name=$(echo "$field" | awk '{print $2}')
        # Check if field exists in CreateRequest and map it
        if grep -q "private .* $field_name;" "$BASE_DIR/dto/request/${model_name}DtoRequest.java"; then
            echo "        updated$model_name.set${field_name^}($lowercase_model_name.get${field_name^}());" >> "$service_impl_file"
        fi
    done
    echo "        log.info(\"$class_name update by id: {}\", updated$model_name);" >> "$service_impl_file"
    echo "        return ${lowercase_model_name}Repository.save(updated$model_name);" >> "$service_impl_file"
    echo "    }" >> "$service_impl_file"
    echo "" >> "$service_impl_file"

    echo "    @Override" >> "$service_impl_file"
    echo "    public Boolean deleteById($id_type id) {" >> "$service_impl_file"
    echo "        log.info(\"$class_name delete by id: {}\", id);" >> "$service_impl_file"   
    echo "        ${lowercase_model_name}Repository.deleteById(id);" >> "$service_impl_file"
    echo "        return true;" >> "$service_impl_file"
    echo "    }" >> "$service_impl_file"
    echo "}" >> "$service_impl_file"
}

mkdir -p "$BASE_DIR"/service/impl

# Iterate over all Java files in the models directory
for model_file in "$MODELS_DIR"/*.java; do
    model_name=$(basename "$model_file" .java)
    if [[ $model_name == *Model ]]; then
        model_name_without_suffix="${model_name%Model}"
        generate_service_impl_class "$model_name" "$model_name_without_suffix"
    else
        generate_service_impl_class "$model_name"
    fi
done

echo "Service implementations generated successfully"

# Function to generate controller class---------------------------------------------------------------------------------------------------------
generate_controller() {
    local model_name="$1"
    local class_name="$1"
    if [ $# -eq 2 ]; then
        model_name="$2"  # Set model_name to second argument
    fi
    local lowercase_model_name=$(echo "${model_name:0:1}" | tr '[:upper:]' '[:lower:]')${model_name:1}
    local controller_file="$CONTROLLER_DIR/${model_name}Controller.java"
    local lowercase_controller_name="${model_name}Controller"
    local request_model_name="$(echo "$lowercase_model_name" | sed 's/\([A-Z]\)/-\1/g' | tr '[:upper:]' '[:lower:]')"
    package_name=$(dirname "${controller_file}" | sed 's|.*java/||; s|/|.|g')

    # Get the type of id
    id_line=$(grep -n "@Id" "$model_file" | head -n 1 | cut -d ":" -f 1)
    private_line=$(awk "NR > $id_line && /private/ {print NR; exit}" "$model_file")
    id_type=$(awk "NR==$private_line" "$model_file" | awk '{print $2}')

    # Add imports for model class and service interface
    echo "package ${package_name};" > "$controller_file"
    echo "" >> "$controller_file"

    echo "import $base_package_name.dto.dtoMapper.${model_name}DtoMapper;" >> "$controller_file"
    echo "import $base_package_name.dto.request.${model_name}DtoRequest;" >> "$controller_file"
    echo "import $base_package_name.dto.response.${model_name}DtoResponse;" >> "$controller_file"
    echo "import $base_package_name.model.$class_name;" >> "$controller_file"
    echo "import $base_package_name.service.impl.${model_name}ServiceImpl;" >> "$controller_file"
    echo "import org.springframework.http.HttpStatus;" >>"$controller_file"
    echo "import org.springframework.http.ResponseEntity;" >> "$controller_file"
    echo "import org.springframework.web.bind.annotation.*;" >> "$controller_file"
    echo "" >> "$controller_file"
    echo "@RestController" >> "$controller_file"
    echo "@RequestMapping(\"/api/$request_model_name\")" >> "$controller_file"
    echo "public class ${model_name}Controller {" >> "$controller_file"
    echo "    private final ${model_name}ServiceImpl ${lowercase_model_name}Service;" >> "$controller_file"
    echo "" >> "$controller_file"
    echo "    public ${model_name}Controller(${model_name}ServiceImpl ${lowercase_model_name}Service) {" >> "$controller_file"
    echo "        this.${lowercase_model_name}Service = ${lowercase_model_name}Service;" >> "$controller_file"
    echo "    }" >> "$controller_file"
    echo "" >> "$controller_file"
    
    # Create create method
    echo "    @PostMapping" >> "$controller_file"
    echo "    public ResponseEntity<${model_name}DtoResponse> create${model_name}(@RequestBody ${model_name}DtoRequest ${lowercase_model_name}DtoRequest) {" >> "$controller_file"
    echo "        ${class_name} ${lowercase_model_name} = ${model_name}DtoMapper.toModel(${lowercase_model_name}DtoRequest);" >> "$controller_file"
    echo "        ${lowercase_model_name} = ${lowercase_model_name}Service.create(${lowercase_model_name});" >> "$controller_file"
    echo "        return new ResponseEntity<>(${model_name}DtoMapper.toResponse(${lowercase_model_name}), HttpStatus.CREATED);" >> "$controller_file"
    echo "    }" >> "$controller_file"
    echo "" >> "$controller_file"
    # Create get method
    echo "    @GetMapping(\"/{id}\")" >> "$controller_file"
    echo "    public ResponseEntity<${model_name}DtoResponse> get${model_name}(@PathVariable(\"id\") ${id_type} id) {" >> "$controller_file"
    echo "        ${class_name} ${lowercase_model_name} = ${lowercase_model_name}Service.getById(id);" >> "$controller_file"
    echo "        return new ResponseEntity<>(${model_name}DtoMapper.toResponse(${lowercase_model_name}), HttpStatus.OK);" >> "$controller_file"
    echo "    }" >> "$controller_file"
    echo "" >> "$controller_file"
    # Create update method
    echo "    @PutMapping(\"/{id}\")" >> "$controller_file"
    echo "    public ResponseEntity<${model_name}DtoResponse> update${model_name}(@PathVariable(\"id\") ${id_type} id, @RequestBody ${model_name}DtoRequest ${lowercase_model_name}DtoRequest) {" >> "$controller_file"
    echo "        ${class_name} ${lowercase_model_name} = ${model_name}DtoMapper.toModel(${lowercase_model_name}DtoRequest);" >> "$controller_file"
    echo "        ${lowercase_model_name} = ${lowercase_model_name}Service.update(id, ${lowercase_model_name});" >> "$controller_file"
    echo "        return new ResponseEntity<>(${model_name}DtoMapper.toResponse(${lowercase_model_name}), HttpStatus.CREATED);" >> "$controller_file"
    echo "    }" >> "$controller_file"
    echo "" >> "$controller_file"
    # Create delete method
    echo "    @DeleteMapping(\"/{id}\")" >> "$controller_file"
    echo "    public ResponseEntity<Boolean> delete${model_name}(@PathVariable(\"id\") ${id_type} id) {" >> "$controller_file"
    echo "        return new ResponseEntity<>(${lowercase_model_name}Service.deleteById(id), HttpStatus.NO_CONTENT);" >> "$controller_file"
    echo "    }" >> "$controller_file"
    echo "}" >> "$controller_file"
}

# Create controller directory if it doesn't exist
CONTROLLER_DIR="$BASE_DIR/controller"
mkdir -p "$CONTROLLER_DIR"

# Iterate over all Java files in the models directory
for model_file in "$MODELS_DIR"/*.java; do
    model_name=$(basename "$model_file" .java)
    if [[ $model_name == *Model ]]; then
        model_name_without_suffix="${model_name%Model}"
        generate_controller "$model_name" "$model_name_without_suffix"
    else
        generate_controller "$model_name"
    fi
done
echo "Controllers generated successfully"