# SpringBooot Microservice Generator bash scripts
### The most lightweight way to generate microservices in SpringBoot: Version 0.0.1
Before you start you have to have created SpringBoot project with created models/entities in separate directory /model
```
module-directory/
│
├─ src/
│  ├─ main/
│  │  ├─ java/
│  │  │  ├─ com/
│  │  │  │  ├─ example/
│  │  │  │  │  ├── module/
│  │  │  │  │  │   └── Entity.java      # Entity class (can have any name)
│  │  │  │  │  ├── Application.java     # Main application class (can have any name)
```
## How to use **microservice-generator.sh**?
1. Put the scripts into the module/directory of your springboot service OR use argument with full path to this directory"
  - `$ bash microservice-generator.sh "/d/My Directory/Projects/JavaProjects/LeetCode/myTest"`
  - ![image](https://github.com/skijl/microvervice-scripts/assets/128129267/b1a50ede-dfcb-4488-bb73-c58cdc69f027)
3. After the first generation part the DTOs will be created. Not you can change them before continuing
  - ![image](https://github.com/skijl/microvervice-scripts/assets/128129267/ee472cee-501c-4602-97c9-24794e2a1794)
4. After adjusting the DTOs you can type Y/y to continue generator script. It will generate another part of the service
  - ![image](https://github.com/skijl/microvervice-scripts/assets/128129267/f6a7a3d0-3304-41ba-a48e-5eec51109730)
## How to use **test-generator.sh**?
1. Put the scripts into the module/directory of your springboot service OR use argument with full path to this directory"
  - `$ bash test-generator.sh "/d/My Directory/Projects/JavaProjects/LeetCode/myTest"`
  - ![image](https://github.com/skijl/microvervice-scripts/assets/128129267/033199bf-ff48-4876-b91b-df6f0704e8a4)
2. The objects used in test generated in a separate directory for easily changing them with the future changes

