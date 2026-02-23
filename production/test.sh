while IFS= read -r resource; do
  echo "Removing: $resource"
  terraform state rm "$resource"
done < problem_resources.txt