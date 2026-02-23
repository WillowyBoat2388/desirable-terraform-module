while IFS= read -r resource; do
  echo "Removing: $resource"
  terraform state rm "$resource"
done < deposed_resources.txt