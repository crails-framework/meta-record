# MetaRecord
MetaRecord is a code generator that allows you to define your application
models using a Ruby-powered DSL, and generates various implementation for
them, for your web server, client, or mobile application.

It can generates code for the following targets:
* Crails-ODB
* ActiveRecord
* Comet.cpp
* Aurelia.js
* Qt

MetaRecord is useful to speed up development of Crails and Comet
application development by generating most of the models code for you.

It is also useful as a way to share the database structure data and the
validations behaviors between frontend and backend.

## MetaRecord DSL
Example of a model definition using MetaRecord's DSL:

```
add_include "app/models/user.hpp", include_in_header: true

Model.add 'Event' do
  order_by 'starts_at'

  visibility :protected
  property 'std::string', 'name'
  property 'std::time_t', 'starts_at'
  property 'double',      'duration', validate: { min: 0 }
  property 'bool',        'enabled', default: true

  has_one  "::User", "owner", validate: { required: true }, read_only: true
  has_many "::User", "subscribers"
end
```

### property
Property declares a new property for your model. Parameters are :

- Type: the standard C++ type. Non-C++ generators will deduce their own native type from this.
- Name: the property name
- Options

Available options:
- default: the property's default value
- read_only: boolean hinting client generators that the property can only be modified by a server application
- validate: an object containing validation details
- db: an object containing database options

Database options:
- transient: a boolean option determining whether the property should be backed in database or not. Set to true so the property won't be persisted. Default is false.
- default: this is the database default value for the property, used in the SQL schema.
- null: a boolean detemining whether an SQL column may accept null or not.
- column: column name to use in SQL databases.
- type: SQL type to use

### has_one
Describes a one to one relationship with another MetaRecord model. This helper will create an id property to store the remote model's id within the current model.

### has_many
Describes a one to many relationship with another MetaRecord model.

### order_by
Defines the property that should be used by default to sort the models when querying the database.

Optionally, you may pass a second parameter `:asc` or `:desc` to change the ordering of the sort.

### resource_name
Allows you to set a resource_name for your model. By default, it will be deduced from the model's name. The resource name is used when converting or reading data from json: a collection parser for a given model will expect to find a key matching the resource_name in any json it receives.

The resource name configured here should be singular. It will be pluralized depending on context (parsing one or multiple models).

### visibility
This command allows you to determine the visibility of the next properties you'll declare. Accepted values are :public, :protected and :private.
