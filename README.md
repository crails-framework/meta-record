# MetaRecord
MetaRecord is a code generator that allows you to define your application
models using a Ruby-powered DSL, and generates various implementation for
them, for your web server, client, or mobile application.

It can generates code for the following targests:
* Crails-ODB
* ActiveRecord
* Comet.cpp
* Aurelia.js

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
