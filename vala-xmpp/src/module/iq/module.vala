using Gee;

using Xmpp.Core;

namespace Xmpp.Iq {
    private const string NS_URI = "jabber:client";

    public class Module : XmppStreamNegotiationModule {
        public const string ID = "iq_module";

        private HashMap<string, ResponseListener> responseListeners = new HashMap<string, ResponseListener>();
        private HashMap<string, ArrayList<Handler>> namespaceRegistrants = new HashMap<string, ArrayList<Handler>>();

        public void send_iq(XmppStream stream, Iq.Stanza iq, ResponseListener? listener = null) {
            stream.write(iq.stanza);
            if (listener != null) {
                responseListeners.set(iq.id, listener);
            }
        }

        public void register_for_namespace(string namespace, Handler module) {
            if (!namespaceRegistrants.has_key(namespace)) {
                namespaceRegistrants.set(namespace, new ArrayList<Handler>());
            }
            namespaceRegistrants[namespace].add(module);
        }

        public override void attach(XmppStream stream) {
            stream.received_iq_stanza.connect(on_received_iq_stanza);
        }

        public override void detach(XmppStream stream) {
            stream.received_iq_stanza.disconnect(on_received_iq_stanza);
        }

        public static Module? get_module(XmppStream stream) {
            return (Module?) stream.get_module(NS_URI, ID);
        }

        public static void require(XmppStream stream) {
            if (get_module(stream) == null) stream.add_module(new Iq.Module());
        }

        public override bool mandatory_outstanding(XmppStream stream) { return false; }

        public override bool negotiation_active(XmppStream stream) { return false; }

        public override string get_ns() { return NS_URI; }
        public override string get_id() { return ID; }

        private void on_received_iq_stanza(XmppStream stream, StanzaNode node) {
            Iq.Stanza iq = new Iq.Stanza.from_stanza(node, Bind.Flag.has_flag(stream) ? Bind.Flag.get_flag(stream).my_jid : null);

            if (iq.type_ == Iq.Stanza.TYPE_RESULT || iq.is_error()) {
                if (responseListeners.has_key(iq.id)) {
                    ResponseListener? listener = responseListeners.get(iq.id);
                    if (listener != null) {
                        listener.on_result(stream, iq);
                    }
                    responseListeners.unset(iq.id);
                }
            } else {
                ArrayList<StanzaNode> children = node.get_all_subnodes();
                if (children.size == 1 && namespaceRegistrants.has_key(children[0].ns_uri)) {
                    ArrayList<Handler> handlers = namespaceRegistrants[children[0].ns_uri];
                    foreach (Handler handler in handlers) {
                        if (iq.type_ == Iq.Stanza.TYPE_GET) {
                            handler.on_iq_get(stream, iq);
                        } else if (iq.type_ == Iq.Stanza.TYPE_SET) {
                            handler.on_iq_set(stream, iq);
                        }
                    }
                } else {
                    Iq.Stanza unaviable_error =  new Iq.Stanza.error(iq, new StanzaNode.build("service-unaviable", "urn:ietf:params:xml:ns:xmpp-stanzas").add_self_xmlns());
                    send_iq(stream, unaviable_error);
                }
            }
        }
    }

    public interface Handler : Object {
        public abstract void on_iq_get(XmppStream stream, Iq.Stanza iq);
        public abstract void on_iq_set(XmppStream stream, Iq.Stanza iq);
    }

    public interface ResponseListener : Object {
        public abstract void on_result(XmppStream stream, Iq.Stanza iq);
    }
}