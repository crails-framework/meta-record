require 'metarecord/generators/qt/base'

class QtHeaderGenerator < GeneratorQtBase
  def reset
    super
    @state = nil
    @relations = {}
    @fields = []
    @transients = []
    @signals = []
  end

  def generate_for object
    reset
    @class_name = object[:name]
    @inherits = object[:inherits]
    _append "class #{@class_name} : public #{super_class}"
    make_block ['{', '};'] do
      generate_qobject object
      generate_transient_members unless @transients.empty?
      unindent do _append "public:" end
      generate_constructor object
      generate_methods object
      generate_signals object
      generate_members object
    end
    @src
  end

  def super_class
    if @inherits.nil?
      self.class.super_class
    else
      @inherits
    end
  end

  def generate_qobject object
    @state = :qproperty
    _append "Q_OBJECT"
    _append "Q_PROPERTY(#{id_type} uid READ getUid WRITE setUid NOTIFY uidChanged)"
    self.instance_eval &object[:block]
  end

  def generate_constructor object
    @state = :constructor
    _append "#{@class_name}(QObject* parent = nullptr);"
  end

  def generate_methods object
    @state = :methods
    self.instance_eval &object[:block]
  end

  def generate_transient_members
    list = []
    macro = "METARECORD_VIRTUAL_PROPERTIES"
    _append "static const QStringList virtualPropertyNames;"
    _append "#{macro}(#{super_class}, virtualPropertyNames)"
  end

  def generate_members object
    @state = :members
    self.instance_eval &object[:block]
  end

  def generate_signals object
    unindent do _append "Q_SIGNALS:" end
    @signals.each do |signal|
      _append "void #{signal}();"
    end
  end

  def property type, name, options = {}
    property_type = type.to_property_type(self)
    type = property_type.name
    member = "m_#{name.lower_camelcase}"
    member = options[:qt][:member] if options[:qt] && options[:qt][:member]
    getter = name.lower_camelcase
    setter = "set#{name.camelcase}"
    signal = "#{name.lower_camelcase}Changed"
    case @state
    when :qproperty
      _append "Q_PROPERTY(#{type} #{name} READ #{getter} WRITE #{setter} NOTIFY #{signal})"
      @transients << name if options[:db] && options[:db][:transient]
      @signals << signal
    when :members
      if options[:qt].nil? || options[:qt][:member].nil?
        if options[:default].nil?
          _append "#{type} #{member};"
        else
          _append "#{type} #{member} = #{get_value options[:default]};"
        end
      end
    when :methods
      getter_options = if options[:qt] && options[:qt][:getter] then options[:qt][:getter] else {} end
      setter_options = if options[:qt] && options[:qt][:setter] then options[:qt][:setter] else {} end
      getter_type = property_type.parameter_type getter_options
      setter_type = property_type.parameter_type setter_options
      getter_override = if getter_options[:override] then " override" else "" end
      setter_override = if setter_options[:override] then " override" else "" end
      _append "virtual #{getter_type} #{getter}() const#{getter_override};"
      _append "virtual void #{setter}(#{setter_type} _value)#{setter_override};"
    end
  end

  def has_one type, name, options = {}
    id_name = "#{name.lower_camelcase}Id"
    getter = name.lower_camelcase
    setter = "set#{name.camelcase}"
    signal = "#{name}Changed"
    member_name = "m_#{name.lower_camelcase}"
    case @state
    when :qproperty
      _append "Q_PROPERTY(#{id_type} #{id_name} MEMBER m_#{id_name} NOTIFY #{signal})"
      _append "Q_PROPERTY(#{type.gsub! /^::/, ''}* #{name} READ #{getter} WRITE #{setter} NOTIFY #{signal})"
      @transients << name
      @signals << signal
    when :constructor
      _append "connect(this, #{@class_name}::#{signal}, this, #{@class_name}::attributeChanged);"
    when :methods
      _append "#{type}* #{getter}() const { return #{member_name}; }"
      _append "METARECORD_MODEL_SETTER_BY_COPY_WITH_SIGNAL(#{type}, #{member_name}, #{setter}, #{signal})"
    when :members
      _append "#{id_type} m_#{id_name} = #{null_id};"
      _append "#{type}* #{member_name} = nullptr;"
    end
  end

  def has_many type, name, options = {}
    qml_getter = "getQml#{name.camelcase}"
    getter = name.lower_camelcase
    setter = "set#{name.camelcase}"
    member_name = "m_#{name.lower_camelcase}"
    signal = "#{name}Changed"
    case @state
    when :qproperty
      @src += "# ifdef METARECORD_WITH_QML\n"
      _append "Q_PROPERTY(QQmlListProperty<#{type}> #{name} READ #{qml_getter} NOTIFY #{signal})"
      @src += "# endif\n"
      @signals << signal
    when :constructor
      _append "registerRelationship(\"#{name}\", #{name});"
    when :methods
      _append "const QList<#{type}*>& #{getter}() const { return #{member_name}; }"
      _append "void #{setter}(const QList<#{type}*>&);"
      @src += "# ifdef METARECORD_WITH_QML\n"
      _append "Q_INVOKABLE QQmlListProperty<#{type}> #{qml_getter}() { return QQmlListProperty<#{type}>(this, &#{member_name}); }"
      @src += "# endif\n"
    when :members
      _append "QList<#{type}*> #{member_name};"
    end
  end

  def visibility name
    case @state
    when :members
      @src += name.to_s + ":\n"
    end
  end

  def resource_name name
    case @state
    when :methods
      _append "static QByteArray resourceName() { return #{name.to_s.inspect}; }"
    end
  end

  def order_by name, flow = nil
    flow_value = if flow == :desc then -1 else 1 end
    case @state
    when :methods
      _append "static QPair<QByteArray, int> orderedBy() { return {#{name.to_s.inspect}, #{flow_value}}; }"
    end
  end

  class << self
    def extension ; ".h" ; end

    def is_file_based? ; true ; end

    def generate_includes
<<CPP
# include <#{super_class_include}>
# include <metarecord-qt/hasOne.h>
# ifdef METARECORD_WITH_QML
#  include <QQmlListProperty>
# endif
CPP
    end

    def make_file filename, data
      file_define = "_#{filename[0...-3].upcase.gsub "/", "_"}_H"
      source = <<CPP
#ifndef  #{file_define}
# define #{file_define}
#{generate_includes}
#{collect_includes_for(filename, true).join "\n"}

#{data[:bodies].join "\n"}
#endif
CPP
    end
  end
end
