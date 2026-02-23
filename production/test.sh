# terraform state rm module.data-workflow.azapi_resource.eventhub_namespace
terraform import module.data-workflow.azapi_resource.eventhub_namespace /subscriptions/75de56f3-8167-4d70-ac37-893b9cfb6840/resourceGroups/ong-hopeful-boar-production/providers/Microsoft.EventHub/namespaces/ong-big-killdeer

terraform state rm module.data-workflow.azapi_resource.workspace
terraform import module.data-workflow.azapi_resource.workspace /subscriptions/75de56f3-8167-4d70-ac37-893b9cfb6840/resourceGroups/ong-hopeful-boar-production/providers/Microsoft.Databricks/workspaces/ong_streamWorkspace-57194

terraform state rm module.data-workflow.azapi_resource.roleAssignment2
terraform import module.data-workflow.azapi_resource.roleAssignment2 /subscriptions/75de56f3-8167-4d70-ac37-893b9cfb6840/resourceGroups/ong-hopeful-boar-production/providers/Microsoft.Authorization/roleAssignments/31cb1eb2-bf89-ee30-9427-13640c8be766

terraform state rm module.data-workflow.azapi_resource.roleAssignment6
terraform import module.data-workflow.azapi_resource.roleAssignment6 /subscriptions/75de56f3-8167-4d70-ac37-893b9cfb6840/resourceGroups/ong-hopeful-boar-production/providers/Microsoft.Authorization/roleAssignments/c77bf563-5138-916f-cbcd-01f3eba0686a


# while IFS= read -r resource; do
#   echo "Removing: $resource"
#   terraform state rm "$resource"
# done < problem_resources.txt