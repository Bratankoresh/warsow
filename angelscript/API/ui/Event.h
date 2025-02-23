/**
 * Event
 */
class Event
{
public:
	/* object properties */

	/* object behaviors */

	/* object methods */
	String@ getType();
	Element@ getTarget();
	String@ getParameter(const String&in, const String&in);
	int getParameter(const String&in, int);
	uint getParameter(const String&in, uint);
	float getParameter(const String&in, float);
	bool getParameter(const String&in, bool);
	Dictionary@ getParameters();
	int getPhase();
	void stopPropagation();
};

