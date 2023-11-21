require 'metarecord/model'
require 'metarecord/generator_base'

class GeneratorQtBase < GeneratorBase
  class << self
    def super_class
      if defined? METARECORD_MODEL_SUPER_CLASS
        METARECORD_MODEL_SUPER_CLASS
      else
        "MetaRecordNotifiable"
      end
    end

    def super_class_include
      if defined? METARECORD_MODEL_SUPER_CLASS_PATH
        METARECORD_MODEL_SUPER_CLASS_PATH
      else
        "metarecord-qt/metarecordnotifiable.h"
      end
    end
  end

  def id_type
    "QByteArray"
  end

  def null_id
    case id_type
    when 'QByteArray' then 'QByteArray()'
    else 0
    end
  end

  def get_type type
    if type.kind_of? Class
      return type.new self if type <= PropertyType
    end
    PropertyType.new(nativeTypeNameFor type)
  end

  def nativeTypeNameFor type
    if type.class == Class
      case type.name
      when 'String'    then 'QString'
      when 'ByteArray' then 'QByteArray'
      when 'Hash'      then 'QVariantMap'
      when 'DateTime'  then 'QDateTime'
      when 'Integer'   then 'qint64'
      when 'Float'     then 'qfloat16'
      when 'Boolean'   then 'bool'
      else type
      end
    else
      case type
      when 'std::string'          then 'QString'
      when 'std::time_t'          then 'QDateTime'
      when 'DataTree'             then 'QJsonObject'
      when 'Crails::Odb::id_type' then id_type
      else type
      end
    end
  end
end
