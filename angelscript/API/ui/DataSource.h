/**
 * DataSource
 */
class DataSource
{
public:
	/* object properties */

	/* object behaviors */

	/* object methods */
	String@ get_name() const;
	int numRows(const String&in) const;
	String@ getField(const String&in, int, const String&in) const;
	int findRow(const String&inout, const String&inout, const String&inout, int = 0) const;
};

