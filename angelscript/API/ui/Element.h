/**
 * Element
 */
class Element
{
public:
	/* object properties */

	/* object behaviors */
	ElementDocument@ _beh_11_();&s
	ElementDataGrid@ _beh_11_();&s
	ElementDataGridRow@ _beh_11_();&s
	ElementForm@ _beh_11_();&s
	ElementFormControl@ _beh_11_();&s
	ElementFormControlDataSelect@ _beh_11_();&s
	ElementTabSet@ _beh_11_();&s
	ElementImage@ _beh_11_();&s
	ElementOptionsForm@ _beh_11_();&s

	/* object methods */
	bool setProp(const String&in, const String&in);
	String@ getProp(const String&in);
	float resolveProp(const String&in, float);
	void removeProp(const String&in);
	Element@ css(const String&in, const String&in);
	String@ css(const String&in);
	void setClass(const String&in, bool);
	bool hasClass(const String&in);
	void setClasses(const String&in);
	String@ getClasses();
	Element@ addClass(const String&in);
	Element@ removeClass(const String&in);
	Element@ toggleClass(const String&in);
	void toggleClass(const String&in, bool);
	void togglePseudo(const String&in, bool);
	bool hasPseudo(const String&in);
	Element@ setAttr(const String&in, const String&in);
	Element@ setAttr(const String&in, int);
	Element@ setAttr(const String&in, float);
	String@ getAttr(const String&in, const String&in);
	int getAttr(const String&in, int);
	int getAttr(const String&in, uint);
	int getAttr(const String&in, float);
	bool hasAttr(const String&in);
	void removeAttr(const String&in);
	int numAttr() const;
	String@ get_tagName() const;
	String@ get_id() const;
	void set_id(const String&in);
	Element@ getParent();
	Element@ getNextSibling();
	Element@ getPrevSibling();
	Element@ firstChild();
	Element@ lastChild();
	uint getNumChildren(bool = false);
	Element@ getChild(uint);
	String@ getInnerRML() const;
	void setInnerRML(const String&in);
	bool focus();
	void unfocus();
	void click();
	void addChild(Element@, bool = true);
	void insertChild(Element@, Element@);
	void removeChild(Element@);
	bool hasChildren() const;
	Element@ clone();
	Element@ getElementById(const String&in);
	Element@[]@ getElementsByTagName(const String&in);
	Element@[]@ getElementsByClassName(const String&in);
	ElementDocument@ get_ownerDocument();
	void addEventListener(const String&inout, DOMEventListenerCallback@);
	void removeEventListener(const String&in, EventListener@);
	float clientLeft();
	float clientTop();
	float clientHeight();
	float clientWidth();
	Element@ offsetParent();
	float offsetLeft();
	float offsetTop();
	float offsetHeight();
	float offsetWidth();
	float scrollLeft();
	void scrollLeft(float);
	float scrollTop();
	void scrollTop(float);
	float scrollHeight();
	float scrollWidth();
	float absLeft();
	float absTop();
};

