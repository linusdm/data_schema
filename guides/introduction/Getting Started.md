# What Are Data Schemas?

Data schemas are declarative descriptions of how to create a struct from some input data. You can set up different schemas to handle different kinds of input data. By default we assume the incoming data is a map, but you can configure schemas to work with any arbitrary data input including XML and json.

Data Schemas really shine when working with API responses - converting the response into trusted internal data easily and efficiently.

## Creating A Simple Schema

Let's think of creating a struct as taking some source data and turning it into the desired struct. To do this we need to know at least three things:

1. The keys of the desired struct
2. The types of the values for each of the keys
3. Where / how to get the data for each value from the source data.

Turning the source data into the correct type defined by the schema will often require casting, so to cater for that the type definitions are casting functions. Let's look at a simple field example

```elixir
field {:content, "text", &cast_string/1}
#       ^          ^                ^
# struct field     |                |
#     path to data in the source    |
#                            casting function
```

This says in the source data there will be a field called `:text`. When creating a struct we should get the data under that field and pass it too `cast_string/1`. The result of that function will be put in the resultant struct under the key `:content`.

There are 4 kinds of struct fields we could want:

1. `field`     - The value will be a casted value from the source data.
2. `list_of`   - The value will be a list of casted values created from the source data.
3. `has_one`   - The value will be created from a nested data schema.
4. `aggregate` - The value will a casted value formed from multiple bits of data in the source.

To see this better let's look at a very simple example. Assume our input data looks like this:

```elixir
source_data = %{
  "content" => "This is a blog post",
  "comments" => [%{"text" => "This is a comment"},%{"text" => "This is another comment"}],
  "draft" => %{"content" => "This is a draft blog post"},
  "date" => "2021-11-11",
  "time" => "14:00:00",
  "metadata" => %{ "rating" => 0}
}
```

And now let's assume the struct we wish to make is this one:

```elixir
%BlogPost{
  content: "This is a blog post",
  comments: [%Comment{text: "This is a comment"}, %Comment{text: "This is another comment"}]
  draft: %DraftPost{content: "This is a draft blog post"}}
  post_datetime: ~N[2020-11-11 14:00:00]
}
```

We can describe the following schemas to enable this:

```elixir
defmodule DraftPost do
  import DataSchema, only: [data_schema: 1]

  data_schema([
    field: {:content, "content", &to_string/1}
  ])
end

defmodule Comment do
  import DataSchema, only: [data_schema: 1]

  data_schema([
    field: {:text, "text", &to_string/1}
  ])

  def cast(data) do
    DataSchema.to_struct!(data, __MODULE__)
  end
end

defmodule BlogPost do
  import DataSchema, only: [data_schema: 1]

  data_schema([
    field: {:content, "content", &to_string/1},
    list_of: {:comments, "comments", Comment},
    has_one: {:draft, "draft", DraftPost},
    aggregate: {:post_datetime, %{date: "date", time: "time"}, &BlogPost.to_datetime/1},
  ])

  def to_datetime(%{date: date, time: time}) do
    date = Date.from_iso8601!(date)
    time = Time.from_iso8601!(time)
    {:ok, datetime} = NaiveDateTime.new(date, time)
    datetime
  end
end
```

Then to transform some input data into the desired struct we can call `DataSchema.to_struct!/2` which works recursively to transform the input data into the struct defined by the schema.

```elixir
source_data = %{
  "content" => "This is a blog post",
  "comments" => [%{"text" => "This is a comment"},%{"text" => "This is another comment"}],
  "draft" => %{"content" => "This is a draft blog post"},
  "date" => "2021-11-11",
  "time" => "14:00:00",
  "metadata" => %{ "rating" => 0}
}

DataSchema.to_struct!(source_data, BlogPost)
# This will output the following:

%BlogPost{
  content: "This is a blog post",
  comments: [%Comment{text: "This is a comment"}, %Comment{text: "This is another comment"}]
  draft: %DraftPost{content: "This is a draft blog post"}}
  post_datetime: ~N[2020-11-11 14:00:00]
}
```

## Different Source Data Types

As we mentioned before we want to be able to handle multiple different kinds of source data in our schemas. For each type of source data we want to be able to specify how you access the data for each field type. We do that by providing a "data accessor" (a module that implements the `DataSchema.DataAccessBehaviour`) when we create the schema. By default if you do not provide a specific data accessor module we use `DataSchema.MapAccessor`. That means the above example is equivalent to doing the following:

```elixir
defmodule DraftPost do
  import DataSchema, only: [data_schema: 2]

  data_schema([
    field: {:content, "content", &to_string/1}
  ], DataSchema.MapAccessor)
end

defmodule Comment do
  import DataSchema, only: [data_schema: 2]

  data_schema([
    field: {:text, "text", &to_string/1}
  ], DataSchema.MapAccessor)

  def cast(data) do
    DataSchema.to_struct!(data, __MODULE__)
  end
end

defmodule BlogPost do
  import DataSchema, only: [data_schema: 2]

  data_schema([
    field: {:content, "content", &to_string/1},
    list_of: {:comments, "comments", Comment},
    has_one: {:draft, "draft", DraftPost},
    aggregate: {:post_datetime, %{date: "date", time: "time"}, &BlogPost.to_datetime/1},
  ], DataSchema.MapAccessor)

  def to_datetime(%{date: date, time: time}) do
    date = Date.from_iso8601!(date)
    time = Time.from_iso8601!(time)
    {:ok, datetime} = NaiveDateTime.new(date, time)
    datetime
  end
end
```
When creating the struct DataSchema will call the relevant function for the field we are creating, passing it the source data and the path to the value(s) in the source. Our `DataSchema.MapAccessor` looks like this:

```elixir
defmodule DataSchema.MapAccessor do
  @behaviour DataSchema.DataAccessBehaviour

  @impl true
  def field(data, field) do
    Map.get(data, field)
  end

  @impl true
  def list_of(data, field) do
    Map.get(data, field)
  end

  @impl true
  def has_one(data, field) do
    Map.get(data, field)
  end

  @impl true
  def aggregate(data, field) do
    Map.get(data, field)
  end
end
```

We can clean up our schema definitions a bit with currying. Instead of passing `DataSchema.MapAccessor` every time we create a schema we can define a helper function like so:

```elixir
defmodule DataSchema.Map do
  defmacro map_schema(fields) do
    quote do
      require DataSchema
      DataSchema.data_schema(unquote(fields), DataSchema.MapAccessor)
    end
  end
end
```

Then change our schema definitions to look like this:

```elixir
defmodule DraftPost do
  import DataSchema.Map, only: [map_schema: 1]

  map_schema([
    field: {:content, "content", &to_string/1}
  ])
end

defmodule Comment do
  import DataSchema.Map, only: [map_schema: 1]

  map_schema([
    field: {:text, "text", &to_string/1}
  ])

  def cast(data) do
    DataSchema.to_struct!(data, __MODULE__)
  end
end

defmodule BlogPost do
  import DataSchema.Map, only: [map_schema: 1]

  map_schema([
    field: {:content, "content", &to_string/1},
    list_of: {:comments, "comments", Comment},
    has_one: {:draft, "draft", DraftPost},
    aggregate: {:post_datetime, %{date: "date", time: "time"}, &BlogPost.to_datetime/1},
  ])

  def to_datetime(%{date: date_string, time: time_string}) do
    date = Date.from_iso8601!(date_string)
    time = Time.from_iso8601!(time_string)
    {:ok, datetime} = NaiveDateTime.new(date, time)
    datetime
  end
end
```

This means should we want to change how we access data (say we wanted to use `Map.fetch!` instead of `Map.get`) we would only need to change the accessor used in one place - inside `map_schema/1`.