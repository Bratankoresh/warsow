/**
 * ElementDataGrid
 */
class ElementDataGrid
{
public:
	/* object properties */

	/* object behaviors */
	Element@ _beh_11_();&s

	/* object methods */
	ElementDataGridRow@ getRow(uint);
	uint getNumRows() const;
	String@[]@ getFields(int) const;
	Element@ getColumnHeader(int);
	uint getNumColumns() const;
	void setDataSource(const String&in);
};

