def build_chart(queryset, label_field='date', value_field='count'):
    return [
        {
            "label": str(entry[label_field]),
            "value": entry.get(value_field, 0),
        }
        for entry in queryset
        if entry.get(label_field) is not None
    ]
