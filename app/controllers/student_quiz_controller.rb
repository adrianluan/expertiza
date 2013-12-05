class StudentQuizController < ApplicationController
  def list
    @participant = AssignmentParticipant.find(params[:id])
    return unless current_user_id?(@participant.user_id)

    @assignment = @participant.assignment

    # Find the current phase that the assignment is in.
    @quiz_phase = @assignment.get_current_stage(AssignmentParticipant.find(params[:id]).topic_id)

    @quiz_mappings = QuizResponseMap.find_all_by_reviewer_id(@participant.id)

    # Calculate the number of quizzes that the user has completed so far.
    @num_quizzes_total = @quiz_mappings.size

    @num_quizzes_completed = 0
    @quiz_mappings.each do |map|
      @num_quizzes_completed += 1 if map.response
    end

    if @assignment.staggered_deadline?
      @quiz_mappings.each { |quiz_mapping|
        if @assignment.team_assignment?
          participant = AssignmentTeam.get_first_member(quiz_mapping.reviewee_id)
        else
          participant = quiz_mapping.reviewee
        end

        if !participant.nil? and !participant.topic_id.nil?
          quiz_due_date = TopicDeadline.find_by_topic_id_and_deadline_type_id(participant.topic_id,1)
        end
      }
      deadline_type_id = DeadlineType.find_by_name('quiz').id
    end
  end

  def finished_quiz

  end

  def self.take_quiz assignment_id
    @questionnaire = Array.new
    Team.find_all_by_parent_id(assignment_id).each do |quiz_creator|
      Questionnaire.find_all_by_instructor_id(quiz_creator.id).each do |questionnaire|
        @questionnaire.push(questionnaire)
      end
    end
    return @questionnaire
  end

  def record_response
    questions = Question.find_all_by_questionnaire_id params[:questionnaire_id]
    responses = Array.new
    valid = 0
    questions.each do |question|
      if (QuestionType.find_by_question_id question.id).q_type == 'MCC'
        if params["#{question.id}"] == nil
          valid = 1
        else
          params["#{question.id}"].each do |choice|
            new_response = QuizResponse.new :response => choice, :question_id => question.id, :questionnaire_id => params[:questionnaire_id]
            unless new_response.valid?
              valid = 1
            end
            responses.push(new_response)
          end
        end
      else
        new_response = QuizResponse.new :response => params["#{question.id}"], :question_id => question.id, :questionnaire_id => params[:questionnaire_id]
        unless new_response.valid?
          valid = 1
        end
        responses.push(new_response)
      end
    end

    if valid == 0
      responses.each do |response|
        response.save
      end
      #TODO send assignment id and participant id
      #TODO redirect to finished quiz view after this
      params.inspect
      redirect_to :controller => 'student_quiz', :action => 'finished_quiz', :questionnaire_id => params[:questionnaire_id]
    else
      flash[:error] = "Please answer every question."
      redirect_to :action => :take_quiz, :assignment_id => params[:assignment_id], :reviewer_id => session[:user].id, :questionnaire_id => params[:questionnaire_id]
    end
  end
end
