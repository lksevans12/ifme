class StrategiesController < ApplicationController
  before_filter :if_not_signed_in
  before_action :set_strategy, only: [:show, :edit, :update, :destroy]

  # GET /strategies
  # GET /strategies.json
  def index
    @strategies = Strategy.where(:userid => current_user.id).all
    @page_title = "Strategies"
    @page_new = new_strategy_path
    @page_tooltip = "New strategy"
  end

  # GET /strategies/1
  # GET /strategies/1.json
  def show
    if current_user.id == @strategy.userid
      @page_edit = edit_strategy_path(@strategy)
      @page_tooltip = "Edit strategy"
    else
      link_url = "/profile?userid=" + @strategy.userid.to_s
      the_link = link_to User.where(:id => @strategy.userid).first.name, link_url
      @page_author = the_link.html_safe
    end
    @no_hide_page = false
    if hide_page(@strategy) && @strategy.userid != current_user.id
      respond_to do |format|
        format.html { redirect_to strategies_path }
        format.json { head :no_content }
      end
    else
      @comment = Comment.new
      # @support = Support.new
      @comments = Comment.where(:commented_on => @strategy.id, :comment_type => "strategy").all
      @no_hide_page = true
      @page_title = @strategy.name
    end
  end

  def comment
    @comment = Comment.create!(:comment_type => params[:comment][:comment_type], :commented_on => params[:comment][:commented_on], :comment_by => params[:comment][:comment_by], :comment => params[:comment][:comment], :visibility => params[:comment][:visibility])
    respond_to do |format|
        format.html { redirect_to strategy_path(params[:comment][:commented_on]) }
        format.json { render :show, status: :created, location: Strategy.find(params[:comment][:commented_on]) }
    end

    # Notify commented_on user that they have a new comment
    strategy_user = Strategy.where(id: @comment.commented_on).first.userid

    if (strategy_user != @comment.comment_by)
      commented_on_user = Strategy.where(id: @comment.commented_on).first.userid
      strategy_name = Strategy.where(id: @comment.commented_on).first.name
      cutoff = false
      if @comment.comment.length > 80 
        cutoff = true
      end
      uniqueid = 'comment_on_strategy' + '_' + @comment.id.to_s

      data = JSON.generate({
        user: current_user.name, 
        strategyid: @comment.commented_on,
        strategy: strategy_name,
        commentid: @comment.id,
        comment: @comment.comment[0..80],
        cutoff: cutoff,
        type: 'comment_on_strategy',
        uniqueid: uniqueid
        })

      Notification.create(userid: strategy_user, uniqueid: uniqueid, data: data)
      notifications = Notification.where(userid: strategy_user).order("created_at ASC").all
      Pusher['private-' + commented_on_user.to_s].trigger('new_notification', {notifications: notifications})
    end
  end

  # def support
  #   if !params[:support].nil? && !params[:support][:userid].empty? && !params[:support][:support_type].empty? && !params[:support][:support_id].empty?
  #     params[:userid] = params[:support][:userid]
  #     params[:support_type] = params[:support][:support_type]
  #     params[:support_id] = params[:support][:support_id]
  #   end

  #   support_id = params[:support_id].to_i

  #   if Support.where(userid: params[:userid], support_type: params[:support_type]).exists?
  #     new_support_ids = Support.where(userid: params[:userid], support_type: params[:support_type]).first.support_ids
  #     if new_support_ids.include?(support_id)
  #       new_support_ids.delete(support_id)
  #       the_support = Support.find_by(userid: params[:userid], support_type: params[:support_type])
  #       if new_support_ids.empty?
  #         @support = the_support.destroy
  #       else
  #         @support = the_support.update!(support_ids: new_support_ids)
  #       end
  #     else
  #       new_support_ids = new_support_ids.push(support_id)
  #       the_support = Support.find_by(userid: params[:userid], support_type: params[:support_type])
  #       the_support.update!(support_ids: new_support_ids)
  #     end
  #   else
  #     @support = Support.create!(userid: params[:userid], support_type: params[:support_type], support_ids: Array.new(1, support_id))
  #   end

  #   respond_to do |format|
  #       format.html { redirect_to strategy_path(support_id) }
  #       format.json { render :show, status: :created, location: Strategy.find(support_id) }
  #   end
  # end

  # GET /strategies/new
  def new
    @viewers = current_user.allies_by_status(:accepted)
    @strategy = Strategy.new
    @page_title = "New Strategy"
  end

  # GET /strategies/1/edit
  def edit
    if @strategy.userid == current_user.id
      @viewers = current_user.allies_by_status(:accepted)
      @page_title = "Edit " + @strategy.name
    else
      respond_to do |format|
        format.html { redirect_to strategy_path(@strategy) }
        format.json { head :no_content }
      end
    end
  end

  # POST /strategies
  # POST /strategies.json
  def create
    @strategy = Strategy.new(strategy_params)
    @page_title = "New Strategy"
    @viewers = current_user.allies_by_status(:accepted)
    respond_to do |format|
      if @strategy.save
        format.html { redirect_to strategy_path(@strategy) }
        format.json { render :show, status: :created, location: @strategy }
      else
        format.html { render :new }
        format.json { render json: @strategy.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /strategies
  # POST /strategies.json
  def premade
    premade_category = Category.where(name: 'Meditation', userid: current_user.id)
    if premade_category.exists?
      premade1 = Strategy.create(userid: current_user.id, name: t('strategies.index.premade1_name'), description: t('strategies.index.premade1_description'), category: [premade_category.first.id], comment: false)
    else 
      premade1 = Strategy.create(userid: current_user.id, name: t('strategies.index.premade1_name'), description: t('strategies.index.premade1_description'), comment: false)
    end

    respond_to do |format|
      format.html { redirect_to strategies_path }
      format.json { render :no_content }
    end
  end

  # PATCH/PUT /strategies/1
  # PATCH/PUT /strategies/1.json
  def update
    @page_title = "Edit " + @strategy.name
    @viewers = current_user.allies_by_status(:accepted)
    respond_to do |format|
      if @strategy.update(strategy_params)
        format.html { redirect_to strategy_path(@strategy) }
        format.json { render :show, status: :ok, location: @strategy }
      else
        format.html { render :edit }
        format.json { render json: @strategy.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /strategies/1
  # DELETE /strategies/1.json
  def destroy
    # Remove strategies from existing triggers
    @triggers = Trigger.where(:userid => current_user.id).all

    @triggers.each do |item|
      new_strategy = item.strategies.delete(@strategy.id)
      the_trigger = Trigger.find_by(id: item.id)
      the_trigger.update(strategies: item.strategies)
    end

    @strategy.destroy
    respond_to do |format|
      format.html { redirect_to strategies_path }
      format.json { head :no_content }
    end

  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_strategy
      begin
        @strategy = Strategy.find(params[:id])
      rescue
        if @strategy.blank?
          respond_to do |format|
            format.html { redirect_to strategies_path }
            format.json { head :no_content }
          end
        end
      end
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def strategy_params
      params.require(:strategy).permit(:name, :description, :userid, :comment, {:category => []}, {:viewers => []})
    end

    def hide_page(strategy)
      if Strategy.where(id: strategy.id).exists?
        if Strategy.where(id: strategy.id).first.viewers.include?(current_user.id)
          return false
        end
      end
      return true
    end

    def if_not_signed_in
      if !user_signed_in?
        respond_to do |format|
          format.html { redirect_to new_user_session_path }
          format.json { head :no_content }
        end
      end
    end

end
