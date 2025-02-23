/**
 * ElementFormControlDataSelect
 */
class ElementFormControlDataSelect
{
public:
	/* object properties */

	/* object behaviors */
	Element@ _beh_11_();&s
	ElementFormControl@ _beh_11_();&s

	/* object methods */
	void setDataSource(const String&in);
	int getSelection();
	void setSelection(int);
	int getNumOptions();
	void addOption(const String&inout, const String&inout, int = - 1, bool = true);
	void removeOption(int);
	void removeAllOptions();
	void spin(int);
};

