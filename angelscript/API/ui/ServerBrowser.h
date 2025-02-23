/**
 * ServerBrowser
 */
class ServerBrowser
{
public:
	/* object properties */

	/* object behaviors */

	/* object methods */
	void fullUpdate();
	void refresh();
	bool isUpdating();
	void stopUpdate();
	bool addFavorite(const String&in);
	bool removeFavorite(const String&in);
	void sortByField(const String&in);
	uint getLastActiveTime();
	uint getUpdateId();
};

